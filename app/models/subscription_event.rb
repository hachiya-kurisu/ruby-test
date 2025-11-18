class SubscriptionEvent < ApplicationRecord
  belongs_to :subscription

  monetize :amount_cents

  enum :event_type, {
    initiated: 0,
    confirmed: 1,
    renewed: 2,
    cancelled: 3
  }

  validates :transaction_id, presence: true
  validates :product_id, presence: true
  validates :event_type, presence: true
  validates :raw_payload, presence: true

  scope :processed, -> { where.not(processed_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }
  scope :pending, -> { where(processed_at: nil, failed_at: nil) }
  scope :stuck, -> { pending.where("created_at < ?", 10.minutes.ago) }

  def processed?
    processed_at.present?
  end

  def mark_processed!
    update!(processed_at: Time.current)
  end

  def mark_failed!
    update!(failed_at: Time.current)
  end
end
