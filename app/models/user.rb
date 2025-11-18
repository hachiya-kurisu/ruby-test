class User < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete
    update!(deleted_at: Time.current)
  end

  def active_subscription
    subscriptions.currently_valid.first
  end

  def can_watch?
    !!active_subscription&.can_watch?
  end
end
