class Lesson < ApplicationRecord
  belongs_to :course
  has_many :tutor_messages, dependent: :destroy
  has_many :lesson_completions, dependent: :destroy

  validates :title, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :course_id }

  def to_param = position.to_s

  def next_lesson = course.lessons.where("position > ?", position).first
  def previous_lesson = course.lessons.where("position < ?", position).last
end
