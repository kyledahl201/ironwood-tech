class Lead < ApplicationRecord
  KINDS = %w[consulting newsletter].freeze
  STATUSES = %w[new contacted closed unsubscribed].freeze

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true, if: -> { kind == "consulting" }
  validates :message, length: { maximum: 4_000 }

  scope :recent, -> { order(created_at: :desc) }

  def unsubscribe_token = signed_id(purpose: :unsubscribe)
end
