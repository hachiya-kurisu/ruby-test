class ExpireSubscriptionsJob < ApplicationJob
  queue_as :default

  def perform
    expired = 0

    # all cancelled subscriptions past their expiration date
    Subscription.cancelled.where("current_period_end < ?", Time.current).find_each do |sub|
      sub.expire!
      expired += 1

      Rails.logger.info("Expired subscription #{sub.id} for user #{sub.user.email}")
    end
    Rails.logger.info("ExpireSubscriptionsJob completed: expired #{expired} subscriptions")

    expired
  end
end
