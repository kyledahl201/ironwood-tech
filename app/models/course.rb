class Course < ApplicationRecord
  has_many :lessons, -> { order(:position) }, dependent: :destroy
  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments, source: :user
  has_many :gifts, dependent: :restrict_with_error

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  # A classroom course code ("CS 101"): owning this course opens the classroom
  # lessons, exercises and tutor kit that carry the code.
  validates :code, uniqueness: true, allow_nil: true

  # Stripe's smallest card charge in US dollars is 50 cents.
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 50 }, allow_nil: true

  scope :published, -> { where(published: true).order(:position) }
  # Every course must be owned to be opened (User#can_open?). Sold courses can
  # be bought in the store; the rest are given by the owner, as a gift.
  scope :sold, -> { where(paid: true) }
  scope :free_to_members, -> { where(paid: false) } # not sold; still owned only by a gift or grant

  def to_param = slug

  # A sold course with no price yet is listed but can't be bought.
  def on_sale? = paid? && published? && price_cents.present?

  def price = price_cents ? format("$%.2f", price_cents / 100.0).sub(/\.00\z/, "") : nil

  # The self-contained player for this course, when it ships one.
  def player = CoursePlayer.for(self)

  def outcome_list = outcomes.to_s.lines.map(&:strip).reject(&:blank?)
end
