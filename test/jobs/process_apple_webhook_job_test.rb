require "test_helper"

class ProcessAppleWebhookJobTest < ActiveJob::TestCase
  test "when event is deleted before job runs" do
    subscription = subscriptions(:provisional_subscription)

    event = subscription.subscription_events.create!(
      event_type: :confirmed,
      transaction_id: subscription.transaction_id,
      product_id: "com.samansa.subscription.monthly",
      purchase_date: Time.current,
      expires_date: 1.month.from_now,
      raw_payload: { test: true }
    )

    # enqueue the job, but delete the event before we perform it
    event_id = event.id
    job = ProcessAppleWebhookJob.perform_later(event_id)
    event.destroy!

    assert_nothing_raised do
      perform_enqueued_jobs
    end

    assert_performed_jobs 1
  end

  test "marks event as failed after all retries exhausted" do
    subscription = subscriptions(:provisional_subscription)

    # use invalid state transition to trigger error
    subscription.update!(status: :provisional)

    event = subscription.subscription_events.create!(
      event_type: :renewed,  # can't renew provisional subscription
      transaction_id: subscription.transaction_id,
      product_id: "com.example.monthly",
      purchase_date: Time.current,
      expires_date: 1.month.from_now,
      raw_payload: { test: true }
    )

    # job should fail and eventually be discarded
    perform_enqueued_jobs do
      ProcessAppleWebhookJob.perform_later(event.id)
    end

    # should be marked as failed (not processed)
    event.reload
    assert_not_nil event.failed_at, "event should be marked as failed"
    assert_nil event.processed_at, "event should not be marked as processed"
  end
end
