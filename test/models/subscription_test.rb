require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "activate! raises error when subscription is not provisional" do
    subscription = subscriptions(:active_subscription)

    error = assert_raises(SubscriptionErrors::InvalidTransition) do
      subscription.activate!(
        purchase_date: Time.current,
        expires_date: 1.month.from_now
      )
    end

    assert_match /can only activate provisional subscriptions/, error.message
  end

  test "cancel! raises error when subscription is not active" do
    subscription = subscriptions(:provisional_subscription)

    error = assert_raises(SubscriptionErrors::InvalidTransition) do
      subscription.cancel!
    end

    assert_match /can only cancel active subscriptions/, error.message
  end

  test "expire! raises error when subscription is not cancelled" do
    subscription = subscriptions(:active_subscription)

    error = assert_raises(SubscriptionErrors::InvalidTransition) do
      subscription.expire!
    end

    assert_match /can only expire cancelled/, error.message
  end

  test "expire! raises error when subscription hasn't reached expiration date" do
    subscription = subscriptions(:cancelled_subscription)

    error = assert_raises(SubscriptionErrors::InvalidTransition) do
      subscription.expire!
    end

    assert_match /subscription hasn't expired yet/, error.message
  end

  test "days_until_expiration calculates days remaining for cancelled subscription" do
    subscription = subscriptions(:cancelled_subscription)

    days = subscription.days_until_expiration

    assert_operator days, :>, 0
    assert_operator days, :<=, 8
  end

  test "days_until_expiration returns 0 when current_period_end is nil" do
    subscription = subscriptions(:provisional_subscription)

    assert_equal 0, subscription.days_until_expiration
  end

  test "validates period_end is after period_start" do
    subscription = subscriptions(:provisional_subscription)

    subscription.current_period_start = Time.current
    subscription.current_period_end = 1.day.ago

    assert_not subscription.valid?
    assert_includes subscription.errors[:current_period_end], "must be after period start"
  end
end
