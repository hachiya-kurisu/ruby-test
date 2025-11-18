module Api
  module V1
    class SubscriptionsController < ApplicationController
      # POST /api/v1/subscriptions
      def create
        user = User.active.find(params[:user_id])

        subscription = Subscriptions::CreateService.create(
          user: user,
          transaction_id: params[:transaction_id],
          product_id: params[:product_id]
        )

        render json: {
          subscription_id: subscription.id,
          status: subscription.status,
          transaction_id: subscription.transaction_id,
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      rescue SubscriptionErrors::AlreadySubscribed => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
