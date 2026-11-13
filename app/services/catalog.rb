# The one course list. The Courses page, the classroom's "switch class" list
# and the welcome screen all read it, so a course looks the same everywhere.
#
# A course is the classroom lessons that share a course code, an online
# reading course, or both (config/course_catalog.yml pairs them up).
class Catalog
  FILE = Rails.root.join("config/course_catalog.yml")
  # Where a course goes until the faculty place it in a department.
  OTHER = "More courses".freeze

  # course is the online reading course, when there is one. access_course is
  # the Course a student must own to open anything in the entry: the course
  # for its code (Catalog.sync_courses!), else the reading course.
  Entry = Struct.new(:slug, :code, :program, :title, :professor, :level, :time, :tagline, :outcomes, :course, :lessons, :done, :open, :started, :enrollment,
                     :access_course, :owned, keyword_init: true) do
    def to_param = slug
    def owned? = owned
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

  # Every classroom course gets a Course record carrying its code, so it can
  # be owned: given by the owner, or as a gift. Run by db/seeds.rb on every
  # start; safe to run again. A course paired with a reading course uses that
  # course. New records are published, not sold, and keep any text the owner
  # edits later.
  def self.sync_courses!
    codes = ClassLesson.distinct.pluck(:course_code)
    described = rows.select { |row| row[:code].present? }
    described.each_with_index do |row, i|
      reading = row[:reading] && Course.find_by(slug: row[:reading])
      if reading
        reading.update!(code: row[:code]) unless Course.exists?(code: row[:code]) # never moves a code students already own
        next
      end
      next unless codes.include?(row[:code])
      ensure_course(row[:code], slug: row[:slug] || row[:code].parameterize, position: 50 + i, title: row[:title], tagline: row[:tagline],
                                level: row[:level], hours: row[:time], outcomes: Array(row[:outcomes]).join("\n"), tutor_name: row[:professor])
    end
    (codes - described.map { |row| row[:code] }).sort.each_with_index do |code, i|
      ensure_course(code, slug: code.parameterize, position: 90 + i, title: code)
    end
  end

  def self.ensure_course(code, slug:, title:, **attrs)
    return if slug.blank? || Course.exists?(code: code)
    course = Course.find_or_initialize_by(slug: slug)
    course.code = code
    course.assign_attributes(attrs.merge(title: title.presence || code, published: true, paid: false).compact) if course.new_record?
    course.save!
  end

  attr_reader :entries

  def initialize(user)
    lessons = ClassLesson.ordered.to_a.group_by(&:course_code)
    progresses = user.class_progresses.to_a
    done = progresses.select(&:completed?).map(&:class_lesson_id).to_set
    started = progresses.select { |p| p.step_index.positive? }.map(&:class_lesson_id).to_set
    open = lessons.values.flatten.select { |l| l.unlocked_for?(user) }.map(&:id).to_set
    # Sold courses live in the store, not in this list.
    courses = Course.published.free_to_members.includes(:lessons).index_by(&:slug)
    by_code = Course.where.not(code: nil).index_by(&:code)
    enrollments = user.enrollments.active.includes(:lesson_completions).index_by(&:course_id)
    owns = ->(course) { course.present? && (user.admin? || enrollments.key?(course.id)) }

    paired = []
    @entries = self.class.rows.filter_map do |row|
      course = courses[row[:reading]]
      paired << course if course
      list = lessons[row[:code]] || []
      next if list.empty? && course.nil?
      access = by_code[row[:code]] || course
      Entry.new(access_course: access, owned: owns.call(access), slug: row[:slug] || course&.slug || row[:code].parameterize, code: row[:code], program: row[:program] || OTHER,
                title: row[:title] || course&.title || row[:code], professor: row[:professor] || list.first&.professor || course&.tutor_name,
                level: row[:level] || course&.level, time: row[:time] || course&.hours, tagline: row[:tagline] || course&.tagline,
                outcomes: row[:outcomes] || course&.outcome_list || [], course: course, lessons: list, done: done, open: open,
                started: list.any? { |l| started.include?(l.id) }, enrollment: course && enrollments[course.id])
    end
    # Classroom courses nobody has described yet still show, under their code.
    (lessons.keys - @entries.map(&:code)).sort.each do |code|
      list = lessons[code]
      access = by_code[code]
      @entries << Entry.new(access_course: access, owned: owns.call(access), slug: code.parameterize, code: code, program: OTHER, title: code, professor: list.first.professor, outcomes: [], lessons: list,
                            done: done, open: open, started: list.any? { |l| started.include?(l.id) })
    end
    # A course that carries a classroom code is the classroom course itself, not a reading course of its own.
    (courses.values - paired).reject { |course| by_code.key?(course.code) }.each do |course|
      @entries << Entry.new(access_course: course, owned: owns.call(course), slug: course.slug, program: OTHER, title: course.title, professor: course.tutor_name, level: course.level, time: course.hours, tagline: course.tagline,
                            outcomes: course.outcome_list, course: course, lessons: [], done: done, open: open, started: false, enrollment: enrollments[course.id])
    end
  end

  def find(slug) = entries.find { |e| e.slug == slug }
  def for_code(code) = entries.find { |e| e.code == code }
  # The entry a Course opens, for links after it's bought or claimed.
  def for_course(course) = entries.find { |e| e.access_course == course || e.course == course }
  def owned = entries.select(&:owned?)
end
