# A lesson script written by a professor. The classroom plays its steps one at
# a time. Scripts hold tasks, checks and hints, never solutions.
class ClassLesson < ApplicationRecord
  STEP_KINDS = %w[teach show try mac quiz].freeze
  MODES = %w[terminal irb ruby pyrepl python].freeze
  # Which kind of tool each mode is, and the checks that make sense in it.
  TOOL_KINDS = { "terminal" => :terminal, "irb" => :console, "pyrepl" => :console, "ruby" => :editor, "python" => :editor }.freeze
  CHECKS_BY_TOOL = {
    terminal: %w[command_matches output_matches cwd_is file_exists dir_exists file_contains],
    console: %w[command_matches output_matches value_is method_returns method_stdout_empty stdout source_includes source_excludes source_matches],
    editor: %w[stdout output_matches method_returns method_stdout_empty value_is source_includes source_excludes source_matches]
  }.freeze
  CHECK_TYPES = (Exercise::CHECK_TYPES + %w[command_matches output_matches cwd_is file_exists dir_exists file_contains value_is]).freeze

  has_many :class_progresses, dependent: :destroy
  has_many :homework_submissions, dependent: :destroy
  has_many :study_records, dependent: :destroy

  validates :slug, :course_code, :lesson_number, :title, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validate :steps_are_playable

  scope :ordered, -> { order(:course_code, :lesson_number) }

  def to_param = slug

  def quiz_count = steps.count { |s| s["kind"] == "quiz" }

  # Open when it's the first lesson of its course, the lesson before it is
  # finished here, or the transcript says the lesson before it was taught.
  def unlocked_for?(user)
    return true if lesson_number <= 1 || tour? || user.admin_preview?
    return true if user.course_records.any? { |r| r.code == course_code && r.lessons_done >= lesson_number - 1 }
    previous = ClassLesson.find_by(course_code: course_code, lesson_number: lesson_number - 1)
    !!previous&.completed_by?(user)
  end

  # The class to take next: one already started, else the first open one not
  # finished, in transcript order (courses in progress first).
  def self.next_for(user)
    done = user.class_progresses.where.not(completed_at: nil).pluck(:class_lesson_id).to_set
    started = user.class_progresses.where(completed_at: nil).where("step_index > 0").order(updated_at: :desc).first&.class_lesson
    return started if started
    records = user.course_records.to_a
    codes = records.select(&:in_progress?).map(&:code)
    taught = records.to_h { |r| [ r.code, r.lessons_done ] } # lessons already taught in chat
    open = ordered.reject { |l| done.include?(l.id) || l.tour? || l.lesson_number <= taught.fetch(l.course_code, 0) || !l.unlocked_for?(user) }
    open = open.select { |l| codes.include?(l.course_code) } if codes.any? # Today never points a student at a course they aren't taking yet
    open.min_by { |l| [ codes.index(l.course_code) || codes.size, l.course_code, l.lesson_number ] }
  end

  # Finished classes whose homework isn't all handed in yet, oldest first.
  def self.homework_due_for(user)
    handed_in = user.homework_submissions.group(:class_lesson_id).count
    joins(:class_progresses).where(class_progresses: { user_id: user.id }).where.not(class_progresses: { completed_at: nil })
      .order("class_progresses.completed_at").select { |l| l.homework.any? && handed_in[l.id].to_i < l.homework.size }
  end

  TOUR = "TOUR".freeze
  def tour? = course_code == TOUR

  def progress_for(user) = class_progresses.find_by(user: user)
  def completed_by?(user) = class_progresses.where(user: user).where.not(completed_at: nil).exists?

  # The Dean's ruling: a lesson finished in the portal counts as taught.
  def self.taught?(user, course_code, lesson_number)
    joins(:class_progresses).where(course_code: course_code, lesson_number: lesson_number..)
      .where(class_progresses: { user_id: user.id }).where.not(class_progresses: { completed_at: nil }).exists?
  end

  private
    def steps_are_playable
      all = Array(steps) + Array(homework)
      errors.add(:steps, "can't be empty") if Array(steps).empty?
      all.each_with_index do |step, i|
        errors.add(:steps, "step #{i + 1} has unknown kind #{step['kind'].inspect}") unless STEP_KINDS.include?(step["kind"])
        errors.add(:steps, "step #{i + 1} has unknown mode #{step['mode'].inspect}") if step["kind"] == "try" && !MODES.include?(step["mode"])
        bad = Array(step["checks"]).map { |c| c["type"] } - CHECK_TYPES
        errors.add(:steps, "step #{i + 1} has unknown check types: #{bad.join(', ')}") if bad.any?
        misfit = step["kind"] == "try" ? Array(step["checks"]).map { |c| c["type"] } - CHECKS_BY_TOOL.fetch(TOOL_KINDS[step["mode"]], CHECK_TYPES) : []
        errors.add(:steps, "step #{i + 1} uses checks that don't work in #{step['mode']}: #{misfit.join(', ')}") if misfit.any? && bad.empty?
        errors.add(:steps, "step #{i + 1} needs at least one check") if %w[try mac].include?(step["kind"]) && Array(step["checks"]).empty?
        errors.add(:steps, "quiz step #{i + 1} needs exactly one right answer") if step["kind"] == "quiz" && Array(step["options"]).count { |o| o["right"] } != 1
      end
    end
end
