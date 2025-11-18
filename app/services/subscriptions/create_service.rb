module Subscriptions
  class CreateService
    attr_reader :user, :transaction_id, :product_id

    def self.create(user:, transaction_id:, product_id:)
      new(user: user, transaction_id: transaction_id, product_id: product_id).create
    end

    def initialize(user:, transaction_id:, product_id:)
      @user = user
      @transaction_id = transaction_id
      @product_id = product_id
    end

    def create
      # if there's an existing subscription with this transaction_id, return it
      existing = Subscription.find_by(user_id: user.id, transaction_id: transaction_id)
      return existing if existing

      ActiveRecord::Base.transaction do
        subscription = user.subscriptions.create!(
          transaction_id: transaction_id,
          product_id: product_id,
          status: :provisional
        )

        subscription.subscription_events.create!(
          event_type: :initiated,
          transaction_id: transaction_id,
          product_id: product_id,
          raw_payload: {
            source: "client",
            transaction_id: transaction_id,
            product_id: product_id
          },
          processed_at: Time.current
        )

        subscription
      end
    rescue ActiveRecord::RecordNotUnique
      raise SubscriptionErrors::AlreadySubscribed, "user is already subscribed"
    end
  end
end
