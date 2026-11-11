class Attempt < ApplicationRecord
  belongs_to :user
  belongs_to :exercise

  validates :code, presence: true, length: { maximum: 20_000 }
  validates :checks_passed, :hints_used, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
