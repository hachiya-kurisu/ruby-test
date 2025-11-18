require "test_helper"

class WebhookEdgeCasesTest < ActionDispatch::IntegrationTest
  test "RENEW webhook on non-active subscription is rejected" do
    subscription = subscriptions(:provisional_subscription)

    # renewing a provisional subscription should fail
    perform_enqueued_jobs do
      post webhooks_apple_url, params: {
        type: "RENEW",
        transaction_id: subscription.transaction_id,
        product_id: "com.samansa.subscription.monthly",
        amount: "3.99",
        currency: "USD",
        purchase_date: Time.current.iso8601,
        expires_date: 1.month.from_now.iso8601
      }, as: :json
    end

    assert_response :success

    event = subscription.subscription_events.where(event_type: :renewed).last
    assert_not_nil event
    assert_not_nil event.failed_at, "event should be marked as failed"
    assert_nil event.processed_at, "event should not be marked as processed"

    subscription.reload

    assert_equal "provisional", subscription.status
  end

  test "webhook with missing fields returns error" do
    post webhooks_apple_url, params: {
      type: "PURCHASE",
      product_id: "com.samansa.subscription.monthly"
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "webhook with an unexpected product_id" do
    subscription = subscriptions(:provisional_subscription)

    post webhooks_apple_url, params: {
      type: "RENEW",
      transaction_id: subscription.transaction_id,
      product_id: "com.samansa.subscription.unknown",
      amount: "3.99",
      currency: "USD",
      purchase_date: Time.current.iso8601,
      expires_date: 1.month.from_now.iso8601
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "concurrent webhook processing is handled safely" do
    subscription = subscriptions(:active_subscription)
    initial_expires = subscription.current_period_end

    # create two events for the same subscription with different expiration dates
    event1 = subscription.subscription_events.create!(
      event_type: :renewed,
      transaction_id: subscription.transaction_id,
      product_id: subscription.product_id,
      amount_cents: 399,
      amount_currency: "USD",
      purchase_date: Time.current,
      expires_date: 1.month.from_now,
      raw_payload: { type: "RENEW", source: "test" }
    )

    event2 = subscription.subscription_events.create!(
      event_type: :renewed,
      transaction_id: subscription.transaction_id,
      product_id: subscription.product_id,
      amount_cents: 399,
      amount_currency: "USD",
      purchase_date: 1.hour.from_now, # different purchase_date to bypass idempotency
      expires_date: 2.months.from_now,
      raw_payload: { type: "RENEW", source: "test" }
    )

    # process both events concurrently using threads
    perform_enqueued_jobs do
      threads = [ event1, event2 ].map do |event|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Subscriptions::ProcessEventService.process(event)
          end
        end
      end

      threads.each(&:join)
    end

    # both events should be marked as processed
    assert_not_nil event1.reload.processed_at
    assert_not_nil event2.reload.processed_at

    # subscription should be updated (no lost updates)
    subscription.reload
    assert_equal "active", subscription.status

    # the expires_date should be one of the two values, not a corrupted state
    assert_includes [ 1.month.from_now.to_date, 2.months.from_now.to_date ],
                    subscription.current_period_end.to_date,
                    "Subscription should have a valid expiration date"

    # should have 2 renewal emails delivered (one per event)
    renewal_emails = ActionMailer::Base.deliveries.select do |mail|
      mail.subject.include?("renewal") || mail.subject.include?("renew")
    end

    assert_equal 2, renewal_emails.count, "Should have exactly 2 renewal emails"
  end
end
