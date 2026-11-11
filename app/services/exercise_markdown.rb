# Parses a professor's exercise file (YAML front matter + Prompt, Starter code,
# Checks and Hints sections) into Exercise attributes. Files never hold solutions.
class ExerciseMarkdown
  def self.parse(text) = new(text).attributes

  def initialize(text)
    @front, @body = text.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)&.captures || raise(ArgumentError, "missing front matter")
  end

  def attributes
    # Simple "key: value" lines; titles may contain colons, so no YAML parser.
    meta = @front.lines.to_h { |l| k, v = l.split(":", 2); [ k.strip, v.to_s.strip ] }
    code, lesson = meta.fetch("id").match(/\A([a-z]+)(\d+)-l(\d+)/).then { |m| [ "#{m[1].upcase} #{m[2]}", m[3].to_i ] }
    {
      slug: meta.fetch("id"), title: meta.fetch("title"), course_code: code, lesson_number: lesson,
      lesson_label: meta["lesson"], weak_spot: meta["weak_spot"], language: meta["language"].presence || "ruby",
      prompt: section("Prompt").strip,
      starter_code: section("Starter code")[/```\w*\n(.*?)```/m, 1].to_s,
      checks: checks, hints: hints
    }
  end

  private
    def section(name)
      @body[/^## #{Regexp.escape(name)}[^\n]*\n(.*?)(?=^## |\z)/m, 1].to_s
    end

    def checks
      rows = section("Checks").lines.map(&:strip).select { |l| l.start_with?("|") }.drop(2)
      rows.map do |row|
        type, call, expected = row.gsub("\\|", "\u0000").split("|")[1..].map { |c| c.strip.tr("\u0000", "|") }
        { "type" => type, "call" => unquote(call), "expected" => expectation(type, expected), "label" => label(type, call, expected) }
      end
    end

    def expectation(type, raw)
      case type
      when "stdout" then unquote(raw).gsub("\\n", "\n")
      when "source_matches" then raw[/`(.+?)`/, 1]
      when "method_stdout_empty" then nil
      else unquote(raw)
      end
    end

    def label(type, call, expected)
      case type
      when "stdout" then "Prints the right output"
      when "method_returns" then "#{unquote(call)} returns #{unquote(expected)}"
      when "method_stdout_empty" then "#{unquote(call)} prints nothing"
      when "source_includes" then "Uses #{unquote(expected)}"
      when "source_excludes" then "Doesn't use #{unquote(expected)}"
      when "source_matches" then expected.sub(/\A.*?`.+?`\s*/, "").delete("()").strip.presence || "Code has the right shape"
      else type
      end
    end

    def unquote(s)
      s.to_s.strip.then { |v| v == "-" ? "" : v }.sub(/\A`(.*)`\z/m, '\1')
    end

    def hints
      section("Hints").lines.filter_map { |l| l[/^\d+\.\s+(.*)/, 1]&.strip }
    end
end
