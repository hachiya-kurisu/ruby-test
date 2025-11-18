require "test_helper"

class UserManagementTest < ActionDispatch::IntegrationTest
  test "user can only have one active subscription at a time" do
    user = users(:alice)
    user.subscriptions.destroy_all

    # create a subscription
    post api_v1_subscriptions_url, params: {
      user_id: user.id,
      transaction_id: "first_txn",
      product_id: "com.samansa.subscription.monthly"
    }, as: :json

    assert_response :created

    # activate it
    perform_enqueued_jobs do
      post webhooks_apple_url, params: {
        type: "PURCHASE",
        transaction_id: "first_txn",
        product_id: "com.samansa.subscription.monthly",
        amount: "9.99",
        currency: "USD",
        purchase_date: Time.current.iso8601,
        expires_date: 1.month.from_now.iso8601
      }, as: :json
    end

    # try to create second subscription
    post api_v1_subscriptions_url, params: {
      user_id: user.id,
      transaction_id: "second_txn",
      product_id: "com.samansa.subscription.monthly"
    }, as: :json

    assert_response :unprocessable_entity
    response_body = JSON.parse(response.body)
    assert_match /already subscribed/i, response_body["error"]
  end

  test "soft deleted user cannot create subscription" do
    user = users(:alice)
    user.subscriptions.destroy_all
    user.soft_delete

    post api_v1_subscriptions_url, params: {
      user_id: user.id,
      transaction_id: "should_fail",
      product_id: "com.samansa.subscription.monthly"
    }, as: :json

    assert_response :not_found
  end
end
