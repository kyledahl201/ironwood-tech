class Course < ApplicationRecord
  has_many :lessons, -> { order(:position) }, dependent: :destroy
  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments, source: :user

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :published, -> { where(published: true).order(:position) }

  def to_param = slug

  # A course with no price is listed but not yet on sale.
  def on_sale? = !price_cents.nil?
  def free? = price_cents == 0

  def price
    return "Price coming soon" unless on_sale?
    free? ? "Free" : format("$%.2f", price_cents / 100.0).sub(/\.00\z/, "")
  end

  def outcome_list = outcomes.to_s.lines.map(&:strip).reject(&:blank?)
end
