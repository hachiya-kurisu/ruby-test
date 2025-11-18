require "test_helper"

module Webhooks
  class AppleControllerTest < ActionDispatch::IntegrationTest
    def send_webhook(params = {})
      defaults = {
        type: "PURCHASE",
        transaction_id: "txn_test",
        product_id: "com.samansa.subscription.monthly",
        amount: "3.9",
        currency: "USD",
        purchase_date: Time.current.iso8601,
        expires_date: 1.month.from_now.iso8601
      }

      post webhooks_apple_url, params: defaults.merge(params), as: :json
    end

    test "PURCHASE (activates provisional subscription)" do
      subscription = subscriptions(:provisional_subscription)

      perform_enqueued_jobs do
        send_webhook(transaction_id: subscription.transaction_id)
      end

      assert_response :ok
      assert_equal "active", subscription.reload.status
      assert subscription.can_watch?
    end

    test "RENEW (updates subscription dates)" do
      subscription = subscriptions(:active_subscription)
      new_expiry = 2.months.from_now

      perform_enqueued_jobs do
        send_webhook(
          type: "RENEW",
          transaction_id: subscription.transaction_id,
          expires_date: new_expiry.iso8601
        )
      end

      assert_response :ok
      assert_equal new_expiry.to_i, subscription.reload.current_period_end.to_i
    end

    test "CANCEL (cancels subscription)" do
      subscription = subscriptions(:active_subscription)

      perform_enqueued_jobs do
        send_webhook(type: "CANCEL", transaction_id: subscription.transaction_id)
      end

      assert_response :ok
      subscription.reload
      assert_equal "cancelled", subscription.status
      assert subscription.can_watch?
    end

    test "duplicate webhooks are idempotent" do
      subscription = subscriptions(:provisional_subscription)
      5.times { send_webhook(transaction_id: subscription.transaction_id) }
      assert_equal 1, subscription.subscription_events.where(event_type: :confirmed).count
    end

    test "webhook for non-existent subscription returns 422" do
      send_webhook(transaction_id: "unknown")
      assert_response :unprocessable_entity
    end

    test "full subscription flow (user creates subscription - webhook activates) " do
      user = users(:alice)
      user.subscriptions.destroy_all

      txn = "full_flow"

      post api_v1_subscriptions_url, params: {
        user_id: user.id,
        transaction_id: txn,
        product_id: "com.samansa.subscription.monthly"
      }, as: :json

      subscription = Subscription.find_by(transaction_id: txn)
      assert_equal "provisional", subscription.status

      perform_enqueued_jobs { send_webhook(transaction_id: txn) }

      assert_equal "active", subscription.reload.status
      assert user.can_watch?
    end
  end
end
