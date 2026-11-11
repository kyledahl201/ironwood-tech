class Course < ApplicationRecord
  has_many :lessons, -> { order(:position) }, dependent: :destroy
  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments, source: :user

  validates :title, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  scope :published, -> { where(published: true).order(:position) }

  def to_param = slug

  def outcome_list = outcomes.to_s.lines.map(&:strip).reject(&:blank?)
end
