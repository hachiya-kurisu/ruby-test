require "test_helper"

module Subscriptions
  class ProcessEventServiceTest < ActiveSupport::TestCase
    test "does not reprocess already processed events" do
      subscription = subscriptions(:active_subscription)

      event = subscription.subscription_events.create!(
        event_type: :renewed,
        transaction_id: subscription.transaction_id,
        product_id: subscription.product_id,
        purchase_date: Time.current,
        expires_date: 1.month.from_now,
        raw_payload: { test: true }
      )

      # mark event as already processed
      event.mark_processed!
      original_updated_at = subscription.reload.updated_at

      # try to process it again
      ProcessEventService.process(event)

      # should not have been updated
      assert_equal original_updated_at, subscription.reload.updated_at
    end

    test "raises error for unknown event type" do
      subscription = subscriptions(:active_subscription)

      event = subscription.subscription_events.create!(
        event_type: :confirmed,
        transaction_id: subscription.transaction_id,
        product_id: subscription.product_id,
        purchase_date: Time.current,
        expires_date: 1.month.from_now,
        raw_payload: { test: true }
      )

      # bypass enum validation
      event.update_column(:event_type, 999)

      error = assert_raises(ArgumentError) do
        ProcessEventService.process(event)
      end

      assert_match /unknown event type/, error.message
    end
  end
end
