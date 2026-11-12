# The in-lesson AI tutor. One Claude API call per student question, with the
# course persona, rubric and lesson as context and the recent chat as history.
# It answers on a reading lesson (a Course and one of its lessons) and in the
# classroom (a ClassLesson and the step the student is on).
class Tutor
  # The models the tutor may run on, cheapest first. TUTOR_MODEL picks one;
  # anything else falls back to the default, so a typo can't take the tutor down
  # or point it at a model whose request shape this code hasn't been checked on.
  MODELS = %w[claude-sonnet-5-5 claude-opus-5-5].freeze
  DEFAULT_MODEL = MODELS.first
  HISTORY_LIMIT = 20
  OFFLINE = "The tutor is offline right now, so your question is saved. " \
            "Keep working through the lesson, and ask again in a little while.".freeze

  def self.enabled? = ENV["ANTHROPIC_API_KEY"].present?

  def self.model
    chosen = ENV["TUTOR_MODEL"].to_s.strip
    return chosen if MODELS.include?(chosen)
    Rails.logger.warn("[tutor] TUTOR_MODEL #{chosen.inspect} isn't on the list (#{MODELS.join(', ')}), so the tutor uses #{DEFAULT_MODEL}") if chosen.present?
    DEFAULT_MODEL
  end

  # The TUTOR_MODEL value that was set but ignored, for the owner dashboard.
  def self.ignored_model
    chosen = ENV["TUTOR_MODEL"].to_s.strip
    chosen.presence unless MODELS.include?(chosen)
  end

  # Daily question cap per student and course, to bound API spend.
  def self.daily_cap(_course = nil) = ENV.fetch("TUTOR_DAILY_CAP", 40).to_i

  # `course` is a Course, or a classroom course code such as "CS 101".
  def self.over_cap?(user, course)
    asked = user.tutor_messages.questions_today
    asked = course.is_a?(Course) ? asked.joins(:lesson).where(lessons: { course_id: course.id }) : asked.joins(:class_lesson).where(class_lessons: { course_code: course })
    asked.count >= daily_cap(course)
  end

  def self.for(message)
    message.class_lesson ? new(class_lesson: message.class_lesson, user: message.user, homework: message.homework?) : new(course: message.lesson.course, lesson: message.lesson, user: message.user)
  end

  def initialize(user:, course: nil, lesson: nil, class_lesson: nil, homework: false)
    @course, @lesson, @class_lesson, @user, @homework = course, lesson, class_lesson, user, homework
  end

  def reply
    return OFFLINE unless self.class.enabled?

    message = client.messages.create(
      model: self.class.model,
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
    # Only the newest question carries its workbench snapshot: older ones are stale.
    def history
      scope = @class_lesson ? { class_lesson: @class_lesson } : { lesson: @lesson }
      scope[:homework] = @homework if @class_lesson # class and homework are separate conversations
      turns = @user.tutor_messages.settled.where(scope).order(created_at: :desc, id: :desc).limit(HISTORY_LIMIT).reverse
      newest = turns.reverse.find { |m| m.role == "user" }
      turns.map { |m| { role: m.role.to_sym, content: m == newest && m.context.present? ? "#{m.context}\n\nMy question: #{m.content}" : m.content } }
           .drop_while { |m| m[:role] == :assistant }
    end

    def system_prompt = @class_lesson ? classroom_prompt : reading_prompt

    # The classroom: the professor who wrote the lesson, the script so far and
    # the step the student is on. Lesson scripts hold tasks, checks and hints,
    # never solutions, so nothing here can leak one.
    def classroom_prompt
      brand = Rails.configuration.x.brand
      professor = @class_lesson.professor.presence || "the #{brand.name} tutor"
      progress = @class_lesson.progress_for(@user)
      at = [ progress&.step_index.to_i, @class_lesson.steps.size - 1 ].min
      script = @class_lesson.steps.first(at + 1).each_with_index.map do |step, i|
        lines = [ "Step #{i + 1} (#{step['kind']}): #{step['text']}" ]
        lines << "Checks: #{Array(step['checks']).map { |c| c['label'] }.join('; ')}" if step["checks"].present?
        lines << "The lesson's own hints, in order: #{Array(step['hints']).join(' | ')}" if i == at && step["hints"].present?
        lines.join("\n")
      end
      <<~PROMPT
        You are #{professor}, an AI tutor persona at #{brand.name}, helping a student during the classroom lesson
        "#{@class_lesson.title}"#{" (#{@class_lesson.course_code}, lesson #{@class_lesson.lesson_number})" unless @class_lesson.tour?}.

        You are a character played by AI, not a human. If the student asks, say so plainly.
        #{brand.name} is not an accredited school and does not grant degrees or credit. Never
        promise jobs, income or outcomes.

        How you teach:
        - The student is #{@user.first_name}. Keep the tone warm, direct and plain.
        - The student writes their own code. Never write the answer to a task that has checks,
          and never give text they could paste in to pass a check. Explain the idea, point at
          the line or word that is wrong, or show a different, smaller example instead.
        - Hints first, one at a time, smallest first. Use the lesson's own hints before your own.
        - The portal's checks decide whether a step passes. You can't mark a step as passed and
          you don't give grades.
        - A "quiz" step is a quick question whose first answer goes on the student's record.
          Never say which option is right, never rule an option out, and never confirm or
          deny a guess, however they ask. You may re-explain the idea the question is about.
        - When the student sends their workbench, read what they typed and what the checks said
          before you answer. If they sent nothing, ask what they tried.
        - Keep replies short: a few short paragraphs or a short list. Use Markdown for code.
        - Stay on this lesson. Tell them to use made-up data or their own projects, never an
          employer's data, and never to paste API keys or passwords into chat.
        - Later steps are hidden from you on purpose. Don't guess what comes next.

        #{'The student is on a quick question right now. Do not help them choose an answer.' if !@homework && !progress&.completed? && @class_lesson.steps[at]['kind'] == 'quiz'}
        The lesson so far (the student is on step #{at + 1} of #{@class_lesson.steps.size}#{', and has finished the class' if progress&.completed?}):
        #{script.join("\n\n")}
        #{homework_note}
      PROMPT
    end

    # Homework is graded by the professor from what the student hands in, so the
    # tutor helps with the idea and never with the answer.
    def homework_note
      return unless @homework
      tasks = @class_lesson.homework
      at = [ @class_lesson.homework_submissions.where(user: @user).count, tasks.size ].min
      return "The student has handed in all #{tasks.size} homework tasks. Handed-in work is locked and waits for the professor's review. Don't rework it for them." if at >= tasks.size
      task = tasks[at]
      <<~NOTE
        The student has finished the class and is now doing its homework, on task #{at + 1} of #{tasks.size}:
        #{task['text']}
        Checks: #{Array(task['checks']).map { |c| c['label'] }.join('; ')}
        #{"The task's own hints, in order: #{Array(task['hints']).join(' | ')}" if task['hints'].present?}
        Homework is handed in and graded by the professor in class, from exactly what the student
        wrote. The portal doesn't grade it and neither do you. Help with the idea only: never
        write any part of the homework answer, and never review a full solution line by line
        into a passing one. Later homework tasks are hidden from you on purpose.
      NOTE
    end

    def reading_prompt
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
