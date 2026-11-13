# The one course list. The Courses page, the classroom's "switch class" list
# and the welcome screen all read it, so a course looks the same everywhere.
#
# A course is the classroom lessons that share a course code, an online
# reading course, or both (config/course_catalog.yml pairs them up).
class Catalog
  FILE = Rails.root.join("config/course_catalog.yml")
  # Where a course goes until the faculty place it in a department.
  OTHER = "More courses".freeze

  Entry = Struct.new(:slug, :code, :program, :title, :professor, :level, :time, :tagline, :outcomes, :course, :lessons, :done, :open, :started, :enrollment, keyword_init: true) do
    def to_param = slug
    def classroom? = lessons.any?
    def tour? = code == ClassLesson::TOUR
    def total = classroom? ? lessons.size : course.lessons.size
    def finished_count = classroom? ? lessons.count { |l| done.include?(l.id) } : enrollment&.lesson_completions&.size.to_i

    # :new, :going or :finished, for this student.
    def state
      return :finished if total.positive? && finished_count >= total
      finished_count.positive? || started || (!classroom? && enrollment) ? :going : :new
    end

    # The classroom lesson to open: the first one not finished that is open to
    # this student, else the first lesson (to go through it again).
    def next_lesson = lessons.find { |l| !done.include?(l.id) && open.include?(l.id) } || lessons.first

    def status_line
      unit = classroom? ? (tour? ? "tour" : "class") : "lesson"
      case state
      when :finished then "Finished · #{total} of #{total} #{unit.pluralize(total)}"
      when :going then "In progress · #{finished_count} of #{total} #{unit.pluralize(total)} finished"
      else "Not started · #{total} #{unit.pluralize(total)}"
      end
    end
  end

  def self.rows = YAML.safe_load_file(FILE).map(&:symbolize_keys)

  attr_reader :entries

  def initialize(user)
    lessons = ClassLesson.ordered.to_a.group_by(&:course_code)
    progresses = user.class_progresses.to_a
    done = progresses.select(&:completed?).map(&:class_lesson_id).to_set
    started = progresses.select { |p| p.step_index.positive? }.map(&:class_lesson_id).to_set
    open = lessons.values.flatten.select { |l| l.unlocked_for?(user) }.map(&:id).to_set
    # Sold courses live in the store, not in this list of free ones.
    courses = Course.published.free_to_members.includes(:lessons).index_by(&:slug)
    enrollments = user.enrollments.active.includes(:lesson_completions).index_by(&:course_id)

    paired = []
    @entries = self.class.rows.filter_map do |row|
      course = courses[row[:reading]]
      paired << course if course
      list = lessons[row[:code]] || []
      next if list.empty? && course.nil?
      Entry.new(slug: row[:slug] || course&.slug || row[:code].parameterize, code: row[:code], program: row[:program] || OTHER,
                title: row[:title] || course&.title || row[:code], professor: row[:professor] || list.first&.professor || course&.tutor_name,
                level: row[:level] || course&.level, time: row[:time] || course&.hours, tagline: row[:tagline] || course&.tagline,
                outcomes: row[:outcomes] || course&.outcome_list || [], course: course, lessons: list, done: done, open: open,
                started: list.any? { |l| started.include?(l.id) }, enrollment: course && enrollments[course.id])
    end
    # Classroom courses nobody has described yet still show, under their code.
    (lessons.keys - @entries.map(&:code)).sort.each do |code|
      list = lessons[code]
      @entries << Entry.new(slug: code.parameterize, code: code, program: OTHER, title: code, professor: list.first.professor, outcomes: [], lessons: list,
                            done: done, open: open, started: list.any? { |l| started.include?(l.id) })
    end
    (courses.values - paired).each do |course|
      @entries << Entry.new(slug: course.slug, program: OTHER, title: course.title, professor: course.tutor_name, level: course.level, time: course.hours, tagline: course.tagline,
                            outcomes: course.outcome_list, course: course, lessons: [], done: done, open: open, started: false, enrollment: enrollments[course.id])
    end
  end

  def find(slug) = entries.find { |e| e.slug == slug }
  def for_code(code) = entries.find { |e| e.code == code }
end
