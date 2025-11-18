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
end
