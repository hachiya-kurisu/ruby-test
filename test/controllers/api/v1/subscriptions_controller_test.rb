require "test_helper"

module Api
  module V1
    class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
      test "successfully creates a provisional subscription" do
        user = users(:alice)
        user.subscriptions.destroy_all

        post api_v1_subscriptions_url, params: {
          user_id: user.id,
          transaction_id: "txn_new_provisional",
          product_id: "com.samansa.subscription.monthly"
        }, as: :json


        assert_response :created

        subscription = Subscription.find_by(transaction_id: "txn_new_provisional")
        assert subscription.present?
        assert_equal "provisional", subscription.status
        assert_equal user.id, subscription.user_id

        event = subscription.subscription_events.first
        assert_equal "initiated", event.event_type
      end

      test "returns existing subscription on duplicate transaction_id" do
        user = users(:bob)
        existing = user.active_subscription

        post api_v1_subscriptions_url, params: {
          user_id: user.id,
          transaction_id: existing.transaction_id,
          product_id: existing.product_id
        }, as: :json

        assert_response :created

        json = JSON.parse(response.body)
        assert_equal existing.transaction_id, json["transaction_id"]
      end

      test "fails when user is already subscribed" do
        user = users(:bob)

        post api_v1_subscriptions_url, params: {
          user_id: user.id,
          transaction_id: "new_txn",
          product_id: "com.samansa.subscription.yearly"
        }, as: :json

        assert_response :unprocessable_entity

        json = JSON.parse(response.body)
        assert_includes json["error"], "already subscribed"
      end

      test "user not found" do
        post api_v1_subscriptions_url, params: {
          user_id: 0,
          transaction_id: "new_txn",
          product_id: "com.samansa.subscription.yearly"
        }, as: :json

        assert_response :not_found
      end

      test "blank transaction_id" do
        user = users(:alice)
        user.subscriptions.destroy_all

        post api_v1_subscriptions_url, params: {
          user_id: user.id,
          transaction_id: "",  # triggers validation failure
          product_id: "com.samansa.subscription.yearly"
        }, as: :json

        assert_response :unprocessable_entity
      end
    end
  end
end
