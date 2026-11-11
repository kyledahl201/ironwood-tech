# Reads the registrar's TRANSCRIPT.md (the format Dean Whitfield keeps) and
# stores the headline numbers and course rows for one user. The markdown
# itself is never stored or committed.
class TranscriptImport
  class FormatError < StandardError; end

  COURSE_HEADER = /\|\s*Course\s*\|\s*Professor\s*\|\s*Status\s*\|/i

  attr_reader :snapshot_attrs, :courses

  def initialize(markdown)
    @md = markdown.to_s
    parse
  end

  def self.call(markdown, user:) = new(markdown).save!(user)

  def save!(user)
    TranscriptSnapshot.transaction do
      (user.transcript_snapshot || user.build_transcript_snapshot).update!(snapshot_attrs)
      user.course_records.where.not(code: courses.map { |c| c[:code] }).delete_all
      courses.each_with_index do |attrs, i|
        user.course_records.find_or_initialize_by(code: attrs[:code]).update!(attrs.merge(position: i))
      end
    end
    self
  end

  private
    def parse
      day = @md.match(/Current day:\s*Day\s*(\d+)\s*\(Day 1 = (\d{4}-\d{2}-\d{2})/i)
      raise FormatError, "Couldn't find the 'Current day' line." unless day

      hours = @md.match(/Hours logged:\s*([\d.,]+)\s*of\s*~?([\d,]+)/i)
      gate = @md.match(/Next gate:\s*([^(\n]+?)\s*\(Day\s*(\d+)\),?\s*(.*)$/i)
      phase = @md[/Current phase:\s*(.+)$/i, 1]

      @snapshot_attrs = {
        current_day: day[1].to_i,
        day_one: Date.iso8601(day[2]),
        phase: phase&.strip&.truncate(250),
        hours_logged: hours ? hours[1].delete(",").to_f : 0,
        stage_hours_target: hours && hours[2].delete(",").to_i,
        next_gate_name: gate && gate[1].strip,
        next_gate_day: gate && gate[2].to_i,
        next_gate_goal: gate && gate[3].strip.truncate(250)
      }
      @courses = parse_courses
    end

    def parse_courses
      lines = @md.lines.map(&:strip)
      start = lines.index { |l| l.match?(COURSE_HEADER) }
      return [] unless start

      lines[(start + 2)..].take_while { |l| l.start_with?("|") }.filter_map do |row|
        cells = row.split("|")[1..].map(&:strip)
        name, professor, status, lessons, hours, grade, next_lesson = cells
        code, title = name.to_s.match(/\A([A-Z]{2,4}\s?\d{3})\s+(.+)\z/)&.captures
        next unless code
        logged, target = hours.to_s.split("/").map { |h| h.to_s[/[\d.]+/] }
        {
          code: code, title: title.truncate(120), professor: professor, status: status.to_s.truncate(120),
          lessons_done: lessons.to_i, hours_logged: logged.to_f, hours_target: target&.to_i,
          grade: (grade unless grade.blank? || grade == "-"), next_lesson: next_lesson.to_s.truncate(250)
        }
      end
    end
end
