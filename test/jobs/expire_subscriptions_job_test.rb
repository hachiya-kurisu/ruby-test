require "test_helper"

class ExpireSubscriptionsJobTest < ActiveJob::TestCase
  test "expires cancelled subscriptions past their end date" do
    user = users(:alice)
    user.subscriptions.destroy_all

    subscription = user.subscriptions.create!(
      transaction_id: "expired_txn",
      product_id: "com.samansa.subscription.monthly",
      status: :cancelled,
      current_period_start: 2.months.ago,
      current_period_end: 1.day.ago,
      cancelled_at: 1.week.ago
    )
    assert_equal "cancelled", subscription.status
    ExpireSubscriptionsJob.perform_now
    subscription.reload
    assert_equal "expired", subscription.status
  end

  test "does not expire cancelled subscriptions still within valid period" do
    user = users(:bob)
    user.subscriptions.destroy_all

    subscription = user.subscriptions.create!(
      transaction_id: "future_txn",
      product_id: "com.samansa.subscription.monthly",
      status: :cancelled,
      current_period_start: 1.month.ago,
      current_period_end: 1.day.from_now,
      cancelled_at: 1.day.ago
    )

    assert_equal "cancelled", subscription.status

    ExpireSubscriptionsJob.perform_now

    subscription.reload
    assert_equal "cancelled", subscription.status
  end

  test "does not affect active subscriptions" do
    active_sub = subscriptions(:active_subscription)
    original_status = active_sub.status

    ExpireSubscriptionsJob.perform_now

    active_sub.reload
    assert_equal original_status, active_sub.status
  end
end
