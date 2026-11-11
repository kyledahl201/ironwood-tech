# The in-lesson AI tutor. One Claude API call per student question, with the
# course persona, rubric and lesson as context and the recent chat as history.
class Tutor
  MODEL = :"claude-opus-5-5"
  HISTORY_LIMIT = 20
  OFFLINE = "The tutor is offline right now, so your question is saved. " \
            "Keep working through the lesson, and ask again in a little while.".freeze

  def self.enabled? = ENV["ANTHROPIC_API_KEY"].present?

  # Daily question cap per student and course, to bound API spend.
  def self.daily_cap(_course = nil) = ENV.fetch("TUTOR_DAILY_CAP", 40).to_i

  def self.over_cap?(user, course)
    user.tutor_messages.questions_today.joins(:lesson).where(lessons: { course_id: course.id }).count >= daily_cap(course)
  end

  def initialize(course:, lesson:, user:)
    @course, @lesson, @user = course, lesson, user
  end

  def reply
    return OFFLINE unless self.class.enabled?

    message = client.messages.create(
      model: MODEL,
      max_tokens: 4_000,
      thinking: { type: "adaptive" },
      output_config: { effort: "low" },
      system_: system_prompt,
      messages: history,
      request_options: {
        # Server-side fallback: if the primary model is overloaded, the API
        # retries on its default fallback model instead of failing the student.
        extra_headers: { "anthropic-beta" => "server-side-fallback-2026-07-01" },
        extra_body: { fallbacks: "default" }
      }
    )

    if message.stop_reason == :refusal
      return "I can't help with that one. Let's get back to the lesson. What step are you on?"
    end

    text = message.content.select { |b| b.type == :text }.map(&:text).join("\n").strip
    text.presence || OFFLINE
  rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError, Anthropic::Errors::APIConnectionError => e
    Rails.logger.warn("[tutor] #{e.class}: #{e.message}")
    OFFLINE
  rescue Anthropic::Errors::APIStatusError => e
    Rails.logger.error("[tutor] #{e.class} #{e.status}: #{e.message}")
    OFFLINE
  end

  private
    def client
      @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    end

    # Alternating user/assistant turns, oldest first, ending on the student's question.
    def history
      @user.tutor_messages.settled.where(lesson: @lesson).order(created_at: :desc, id: :desc)
           .limit(HISTORY_LIMIT).reverse
           .map { |m| { role: m.role.to_sym, content: m.content } }
           .drop_while { |m| m[:role] == :assistant }
    end

    def system_prompt
      brand = Rails.configuration.x.brand
      <<~PROMPT
        You are #{tutor_name}, the AI tutor for the #{brand.name} course "#{@course.title}".
        #{@course.tutor_bio}

        You are a character played by AI, not a human. If the student asks, say so plainly.
        #{brand.name} is not an accredited school and does not grant degrees or credit. Never
        promise jobs, income or outcomes.

        How you teach:
        - The student is #{@user.first_name}. Keep the tone warm, direct and plain.
        - Give one step at a time, then wait for their result before the next step.
        - Hints first. Give a full answer only after they've tried and ask for it.
        - When they submit work, review it against the rubric below. Say what meets the bar,
          what doesn't, and the one most useful fix. Be honest when work isn't there yet,
          and remind them they can redo the lesson.
        - When they ask for the quiz, give 5 short questions on this lesson one at a time and
          check each answer. When they ask for "Judge it", show a short broken snippet or
          flawed AI output and let them find the problem.
        - Keep replies short: a few short paragraphs or a short list. Use Markdown for code.
        - Stay on this course. Tell them to use made-up data or their own projects, never
          an employer's data, and never to paste API keys or passwords into chat.

        Course rubric:
        #{@course.rubric.presence || "Clear, working, explained in the student's own words."}

        Current lesson #{@lesson.position}: #{@lesson.title}
        #{@lesson.body}
      PROMPT
    end

    def tutor_name = @course.tutor_name.presence || "the #{Rails.configuration.x.brand.name} tutor"
end
