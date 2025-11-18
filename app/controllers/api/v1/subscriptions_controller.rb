module Api
  module V1
    class SubscriptionsController < ApplicationController
      # POST /api/v1/subscriptions
      def create
        head :ok
      end
    end
  end
end
