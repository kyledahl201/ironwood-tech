# Parses a professor's classroom lesson script (university/website/lessons/FORMAT.md)
# into ClassLesson attributes. Scripts never hold solutions.
class ClassLessonMarkdown
  class FormatError < StandardError; end

  def self.parse(text) = new(text).attributes

  def initialize(text)
    @front, @body = text.to_s.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)&.captures || raise(FormatError, "missing front matter")
  end

  def attributes
    meta = @front.lines.to_h { |l| k, v = l.split(":", 2); [ k.strip, v.to_s.strip.sub(/\A"(.*)"\z/, '\1') ] }
    {
      slug: meta.fetch("id") { raise FormatError, "front matter needs an id" },
      course_code: meta.fetch("course") { raise FormatError, "front matter needs a course" },
      lesson_number: meta["lesson"].to_i, title: meta["title"].to_s, professor: meta["professor"].presence,
      minutes: meta["minutes"].presence&.to_i,
      steps: sections.filter_map { |name, text| step(name[/\AStep:\s*(\w+)/i, 1]&.downcase, text, "###") if name.match?(/\AStep:/i) },
      study_guide: bullets(section_text("Study guide")),
      flashcards: bullets(section_text("Flashcards")).filter_map { |l| front, back = l.split("::", 2).map { |s| s.to_s.strip }; { "front" => front, "back" => back } if back.present? },
      homework: homework
    }
  end

  private
    # Top-level "## Name" sections in order. Fenced code is skipped so a "## "
    # inside a code block never starts a section.
    def sections
      @sections ||= split(@body, "##")
    end

    def split(text, marker)
      out = []
      fenced = false
      text.each_line do |line|
        fenced = !fenced if line.lstrip.start_with?("```")
        if !fenced && line.start_with?("#{marker} ")
          out << [ line.delete_prefix("#{marker} ").strip, +"" ]
        elsif out.any?
          out.last[1] << line
        else
          out << [ "", +line ] # text before the first heading
        end
      end
      out
    end

    def section_text(name) = sections.find { |n, _| n.casecmp?(name) || n.downcase.start_with?(name.downcase) }&.last.to_s

    def bullets(text) = text.lines.filter_map { |l| l[/\A\s*[-*]\s+(.*)/, 1]&.strip }

    def homework
      split(section_text("Homework"), "###").filter_map { |name, text| step("try", text, "####") if name.casecmp?("Task") }
    end

    # One step: optional "key: value" lines, the professor's text, then sub-sections.
    def step(kind, text, marker)
      parts = split(text, marker)
      body = parts.first && parts.first[0] == "" ? parts.shift[1] : ""
      subs = parts.each_with_object({}) { |(n, t), h| (h[n.downcase.split.first] ||= +"") << t }
      settings = {}
      lines = body.lines
      while (m = lines.first&.match(/\A(mode|visual):\s*(\S+)\s*\z/i))
        settings[m[1].downcase] = m[2].downcase
        lines.shift
      end
      result = { "kind" => kind, "text" => lines.join.strip }.merge(settings)
      case kind
      when "quiz" then result.merge!(quiz(result["text"]))
      when "try", "mac"
        result["starter"] = code_block(subs["starter"]) if subs["starter"]
        result["run"] = subs["run"].scan(/```\w*\n(.*?)```/m).map { |m| m.first.strip } if subs["run"]
        result["checks"] = checks(subs["checks"].to_s)
        result["hints"] = subs["hints"].to_s.lines.filter_map { |l| l[/^\d+\.\s+(.*)/, 1]&.strip }
      end
      result
    end

    def code_block(text) = text.to_s[/```\w*\n(.*?)```/m, 1].to_s

    def quiz(text)
      options = text.lines.filter_map { |l| (m = l.match(/\A\s*-\s*\[( |x|X)\]\s*(.+)/)) && { "text" => m[2].strip, "right" => m[1] != " " } }
      explain = text.lines.filter_map { |l| l[/\A>\s*(.*)/, 1] }.join(" ").strip
      question = text.lines.reject { |l| l.match?(/\A\s*-\s*\[|\A>/) }.join.strip
      { "text" => question, "options" => options, "explain" => explain }
    end

    def checks(text)
      rows = text.lines.map(&:strip).select { |l| l.start_with?("|") }.drop(2)
      rows.map do |row|
        type, call, expected = row.gsub("\\|", "\u0000").split("|")[1..].map { |c| c.to_s.strip.tr("\u0000", "|") }
        call = unquote(call)
        value = expectation(type, expected.to_s)
        { "type" => type, "call" => call, "expected" => value, "label" => label(type, call, expected.to_s, value) }
      end
    end

    def expectation(type, raw)
      case type
      when "stdout" then unquote(raw).gsub("\\n", "\n")
      when "source_matches", "command_matches", "output_matches" then raw[/`(.+)`/, 1] || raw.strip
      when "method_stdout_empty" then nil
      else unquote(raw)
      end
    end

    def label(type, call, raw, value)
      note = raw.sub(/\A.*`\s*/, "").delete("()").strip.presence if raw.include?("`")
      case type
      when "stdout" then "Prints the right output"
      when "method_returns" then "#{call} returns #{value}"
      when "method_stdout_empty" then "#{call} prints nothing"
      when "source_includes" then "Uses #{value}"
      when "source_excludes" then "Doesn't use #{value}"
      when "source_matches" then note || "Code has the right shape"
      when "command_matches" then note || "You typed the right command"
      when "output_matches" then note || "The output looks right"
      when "cwd_is" then "You are in #{value}"
      when "file_exists" then "#{value} exists"
      when "dir_exists" then "The folder #{value} exists"
      when "file_contains" then "#{call} contains #{value}"
      when "value_is" then "#{call} is #{value}"
      else type.to_s
      end
    end

    def unquote(s)
      s.to_s.strip.then { |v| v == "-" ? "" : v }.sub(/\A`(.*)`\z/m, '\1')
    end
end
