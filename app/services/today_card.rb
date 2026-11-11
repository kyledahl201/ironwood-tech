# The one action the dashboard leads with (Prof. Duarte: "Today" first).
class TodayCard
  GREETINGS = [
    "Morning, %{name}. Day %{day}. One step today is enough.",
    "Day %{day}. The plan is ready when you are.",
    "Good evening, %{name}. Even 20 minutes counts.",
    "%{hours} hours logged this week. Let's add one.",
    "Day %{day}. Sentry has been waiting. Patiently."
  ].freeze

  attr_reader :title, :detail, :professor, :action_label, :action_path, :kind, :class_lesson, :minutes

  def initialize(user, records:, enrollments:, stats:)
    @user, @stats = user, stats
    @snapshot = user.transcript_snapshot
    if (@class_lesson = ClassLesson.next_for(user))
      started = @class_lesson.progress_for(user)&.step_index.to_i.positive?
      @kind = :classroom
      @title = "#{@class_lesson.course_code} · Lesson #{@class_lesson.lesson_number}"
      @detail = @class_lesson.title
      @professor = @class_lesson.professor
      @minutes = @class_lesson.minutes
      @action_label = started ? "Resume class" : "Start class"
    elsif (record = records.find(&:in_progress?))
      @kind = :class
      @title = "#{record.code} #{record.title}"
      @detail = record.next_lesson
      @professor = record.professor
    elsif (enrollment = enrollments.find { |e| !e.finished? && e.next_lesson })
      lesson = enrollment.next_lesson
      @kind = :lesson
      @title = enrollment.course.title
      @detail = "Lesson #{lesson.position}: #{lesson.title}"
      @professor = enrollment.course.tutor_name
      @action_label = enrollment.lesson_completions.empty? ? "Start" : "Resume"
      @action_path = [ :learn_lesson, enrollment.course, lesson ]
    else
      @kind = :empty
      @title = "Nothing here yet."
      @detail = "Your first lesson is one click away."
    end
  end

  def greeting(now = Time.zone.now)
    hours = @stats.hours_this_week
    day = @snapshot&.current_day
    pool = GREETINGS.reject { |g| g.include?("%{day}") && day.nil? }
    pool = pool.reject { |g| g.start_with?("Morning") } unless now.hour < 12
    pool = pool.reject { |g| g.start_with?("Good evening") } unless now.hour >= 17
    pool = pool.reject { |g| g.include?("%{hours}") } if hours.zero?
    pool = [ "Welcome back, %{name}. One step today is enough." ] if pool.empty?
    format(pool[now.yday % pool.size], name: @user.first_name, day: day, hours: hours)
  end

  def gate
    return nil unless @snapshot&.next_gate_name && @snapshot.next_gate_day
    { name: @snapshot.next_gate_name, days: @snapshot.days_to_next_gate, day: @snapshot.current_day,
      gate_day: @snapshot.next_gate_day, goal: @snapshot.next_gate_goal,
      hours: @stats.total_hours, target: @snapshot.stage_hours_target }
  end
end
