module Subscriptions
  class ProcessEventService
    attr_reader :event, :subscription, :user

    def self.process(event)
      new(event).process
    end

    def initialize(event)
      @event = event
      @subscription = event.subscription
      @user = subscription.user
    end

    def process
      ActiveRecord::Base.transaction do
        subscription.with_lock do
          event.reload
          return if event.processed?

          case event.event_type.to_s.to_sym
          when :confirmed
            handle_confirmed
          when :renewed
            handle_renewal
          when :cancelled
            handle_cancellation
          else
            raise ArgumentError, "unknown event type: #{event.event_type}"
          end

          event.mark_processed!
        end
      end
    rescue SubscriptionErrors::InvalidTransition => e
      # invalid state transition - mark as failed and don't retry
      Rails.logger.error("Invalid state transition for event #{event.id}: #{e.message}")
      event.mark_failed!
    end

    private

    def handle_confirmed
      subscription.activate!(
        purchase_date: event.purchase_date,
        expires_date: event.expires_date
      )

      SubscriptionMailer.with(
        user: user,
        subscription: subscription
      ).welcome.deliver_now
    end

    def handle_renewal
      subscription.renew!(
        purchase_date: event.purchase_date,
        expires_date: event.expires_date
      )

      SubscriptionMailer.with(
        user: user,
        subscription: subscription
      ).renewal.deliver_now
    end

    def handle_cancellation
      subscription.cancel!

      SubscriptionMailer.with(
        user: user,
        subscription: subscription
      ).cancellation.deliver_now
    end
  end
end
