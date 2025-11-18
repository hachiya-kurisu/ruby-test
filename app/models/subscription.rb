class Subscription < ApplicationRecord
  belongs_to :user
  has_many :subscription_events, dependent: :destroy

  enum :status, {
    provisional: 0,
    active: 1,
    cancelled: 2,
    expired: 3
  }

  validates :transaction_id, presence: true, uniqueness: true
  validates :product_id, presence: true
  validates :status, presence: true

  scope :currently_valid, -> {
    where(status: [:active, :cancelled]).order(created_at: :desc)
  }

  # state transitions
  def activate!(purchase_date:, expires_date:)
    unless provisional?
      raise SubscriptionErrors::InvalidTransition, "can only activate provisional subscriptions"
    end

    update!(
      status: :active,
      current_period_start: purchase_date,
      current_period_end: expires_date
    )
  end

  def renew!(purchase_date:, expires_date:)
    unless active?
      raise SubscriptionErrors::InvalidTransition, "can only renew active subscriptions"
    end

    update!(
      current_period_start: purchase_date,
      current_period_end: expires_date
    )
  end

  def cancel!
    unless active?
      raise SubscriptionErrors::InvalidTransition, "can only cancel active subscriptions"
    end

    update!(
      status: :cancelled,
      cancelled_at: Time.current
    )
  end

  def expire!
    unless cancelled?
      raise SubscriptionErrors::InvalidTransition, "can only expire cancelled subscriptions"
    end

    update!(status: :expired)
  end

  def can_watch?
    active? || cancelled?
  end

  def days_until_expiration
    return 0 unless current_period_end
    [ ((current_period_end - Time.current) / 1.day).ceil, 0 ].max
  end
end
