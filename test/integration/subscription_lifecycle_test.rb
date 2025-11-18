require "test_helper"

class SubscriptionLifecycleTest < ActionDispatch::IntegrationTest
  test "complete subscription lifecycle from creation to expiration" do
    user = users(:alice)
    Subscription.destroy_all

    txn = "lifecycle-#{Time.current.to_i}"

    # 1: user initiates subscription
    post api_v1_subscriptions_url, params: {
      user_id: user.id,
      transaction_id: txn,
      product_id: "com.samansa.subscription.monthly"
    }, as: :json

    assert_response :created
    subscription = Subscription.find_by(transaction_id: txn)
    assert_equal "provisional", subscription.status
    assert_not subscription.can_watch?

    # 2: apple confirms purchase
    perform_enqueued_jobs do
      post webhooks_apple_url, params: {
        type: "PURCHASE",
        transaction_id: txn,
        product_id: "com.samansa.subscription.monthly",
        amount: "3.9",
        currency: "USD",
        purchase_date: Time.current.iso8601,
        expires_date: 1.month.from_now.iso8601
      }, as: :json
    end

    subscription.reload
    assert_equal "active", subscription.status
    assert subscription.can_watch?
    assert_emails 1

    # 3: subscription renews 🎉
    perform_enqueued_jobs do
      post webhooks_apple_url, params: {
        type: "RENEW",
        transaction_id: txn,
        product_id: "com.samansa.subscription.monthly",
        amount: "3.9",
        currency: "USD",
        purchase_date: 1.month.from_now.iso8601,
        expires_date: 2.months.from_now.iso8601
      }, as: :json
    end

    subscription.reload
    assert_equal "active", subscription.status
    assert subscription.can_watch?
    assert_emails 2

    # step 4: user cancels 😭
    perform_enqueued_jobs do
      post webhooks_apple_url, params: {
        type: "CANCEL",
        transaction_id: txn,
        product_id: "com.samansa.subscription.monthly",
        amount: "3.9",
        currency: "USD",
        purchase_date: 1.month.from_now.iso8601,
        expires_date: 2.months.from_now.iso8601
      }, as: :json
    end

    subscription.reload
    assert_equal "cancelled", subscription.status
    assert subscription.can_watch?
    assert_not_nil subscription.cancelled_at
    assert_emails 3

    # step 5: time passes, subscription expires 🍂
    travel_to 2.months.from_now + 1.day do
      ExpireSubscriptionsJob.perform_now

      subscription.reload
      assert_equal "expired", subscription.status
      assert_not subscription.can_watch?
    end

    # step 6: another year goes by, user starts a new subscription 🍂
    travel_to 1.year.from_now do
      txn = "lifecycle-#{Time.current.to_i}"

      post api_v1_subscriptions_url, params: {
        user_id: user.id,
        transaction_id: txn,
        product_id: "com.samansa.subscription.monthly"
      }, as: :json

      assert_response :created
      subscription = Subscription.find_by(transaction_id: txn)
      assert_equal "provisional", subscription.status
      assert_not subscription.can_watch?

      # apple confirms purchase (again)
      perform_enqueued_jobs do
        post webhooks_apple_url, params: {
          type: "PURCHASE",
          transaction_id: txn,
          product_id: "com.samansa.subscription.monthly",
          amount: "3.9",
          currency: "USD",
          purchase_date: Time.current.iso8601,
          expires_date: 1.month.from_now.iso8601
        }, as: :json
      end

      subscription.reload
      assert_equal "active", subscription.status
      assert subscription.can_watch?
      assert_emails 4
      assert user.subscriptions.count 2
    end
  end
end
