# Badges for real milestones only. Each is earned once and kept.
module Badges
  Badge = Data.define(:key, :name, :description, :egg)

  # Names and lines from the Office of Communications (copy/portal/03-badges.md).
  ALL = [
    Badge.new("first_run", "Hello, World", "You ran your own code. Everything starts here.", false),
    Badge.new("first_pass", "All Green", "Every check passed on one exercise. Self-checked in the lab.", false),
    Badge.new("no_hints", "Unassisted", "Passed without opening a hint. Self-checked. Sentry noticed.", false),
    Badge.new("streak_7", "Seven Days", "A week in a row, with one grace day included.", false),
    Badge.new("streak_30", "Thirty Days", "A month of showing up. That's the whole secret.", false),
    Badge.new("hours_10", "Ten Hours", "10 hours logged. The first ten are the hardest.", false),
    Badge.new("hours_100", "One Hundred Hours", "100 hours logged. That's real time on the record.", false),
    Badge.new("course_done", "Course Complete", "Every lesson in a course, finished.", false),
    Badge.new("gate_1", "Gate 1", "50 lines of Ruby, written alone.", false),
    Badge.new("gate_2", "Gate 2", "30 Ruby exercises solved alone, and explained out loud.", false),
    Badge.new("gate_3", "Gate 3", "SQL queries and a tested Ruby program, done alone.", false),
    Badge.new("gate_4", "Gate 4", "A tested app, built alone. The Junior Sprint is done.", false),
    Badge.new("comeback", "Back at It", "A week away, then back. Coming back is the skill.", false),
    Badge.new("night_owl", "Night Owl", "Studying between midnight and 4 a.m.? Sentry approves. Your sleep doesn't.", true),
    Badge.new("konami", "Up, Up, Down, Down", "You found it. No extra lives, but respect.", true)
  ].index_by(&:key).freeze

  EGGS = %w[konami].freeze

  module_function

  # Awards anything newly earned; returns the new UserBadge records.
  def award!(user, extra: [])
    earned = user.user_badges.pluck(:key)
    due = (qualifying(user) + extra).uniq - earned
    due.map { |key| user.user_badges.create!(key: key, earned_at: Time.current) }
  end

  def qualifying(user)
    stats = ProgressStats.new(user)
    keys = []
    passes = user.attempts.where(passed: true)
    keys << "first_run" if user.attempts.exists?
    keys << "first_pass" if passes.exists?
    keys << "no_hints" if passes.where(hints_used: 0).exists?
    streak = stats.streak
    keys << "streak_7" if streak >= 7
    keys << "streak_30" if streak >= 30
    hours = stats.total_hours
    keys << "hours_10" if hours >= 10
    keys << "hours_100" if hours >= 100
    keys << "course_done" if user.course_records.any?(&:finished?) || user.enrollments.includes(:lesson_completions, course: :lessons).any?(&:finished?)
    gates_passed(user).times { |i| keys << "gate_#{i + 1}" if i < 4 }
    keys << "comeback" if stats.days_away.to_i >= 7 && stats.active_days.include?(Time.zone.today)
    keys << "night_owl" if night_owl?(user)
    keys
  end

  def gates_passed(user)
    name = user.transcript_snapshot&.next_gate_name.to_s
    n = name[/Gate\s*(\d+)/i, 1]
    n ? n.to_i - 1 : 0
  end

  def night_owl?(user)
    recent = user.attempts.where(created_at: 2.days.ago..).pluck(:created_at) +
             user.study_sessions.where(created_at: 2.days.ago..).pluck(:created_at)
    recent.any? { |t| t.in_time_zone.hour < 4 }
  end
end
