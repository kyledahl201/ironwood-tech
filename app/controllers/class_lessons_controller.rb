# The classroom. A lesson's checks run in the browser (self-checked practice);
# the server keeps the student's place, answers quiz questions and marks the
# lesson finished. Professors still give the grades.
class ClassLessonsController < ApplicationController
  before_action :set_lesson, except: :index
  before_action :require_finished_class, only: %i[homework hand_in]
  rate_limit to: 120, within: 1.minute, by: -> { current_user.id }, with: -> { head :too_many_requests }, only: %i[progress quiz hand_in]

  def index
    @lessons = ClassLesson.ordered.to_a
    @progress = current_user.class_progresses.index_by(&:class_lesson_id)
    @next = ClassLesson.next_for(current_user)
    @handed_in = current_user.homework_submissions.group(:class_lesson_id).count
  end

  def show
    progress = @lesson.class_progresses.find_or_create_by!(user: current_user)
    @steps = @lesson.steps
    @index = progress.step_index
    @tools = VisualizersController::TOOLS
  end

  # Study guide, flashcards and (once class is finished) the quiz again.
  def study
    @progress = @lesson.progress_for(current_user)
    @finished = @progress&.completed? || false
    @quizzes = @finished ? @lesson.steps.each_with_index.select { |step, _| step["kind"] == "quiz" } : []
    @submissions = @lesson.homework_submissions.where(user: current_user).order(:task_index).to_a
    @handed_in = @submissions.size
  end

  # Homework plays in the same classroom, one task at a time.
  def homework
    return redirect_to study_class_lesson_path(@lesson), notice: "This lesson has no homework." if @lesson.homework.empty?
    @homework = true
    @steps = @lesson.homework
    @index = [ @lesson.homework_submissions.where(user: current_user).count, @steps.size ].min
    @tools = VisualizersController::TOOLS
    render :show
  end

  # A homework task passed its checks in the browser. The student's work is
  # kept for the professor, who reviews and grades it; the portal never does.
  def hand_in
    done = @lesson.homework_submissions.where(user: current_user).count
    task = params[:task_index].to_i
    return render json: { ok: false, error: "Homework tasks are handed in one at a time." }, status: :unprocessable_entity unless task.between?(0, [ done, @lesson.homework.size - 1 ].min)
    submission = @lesson.homework_submissions.find_or_initialize_by(user: current_user, task_index: task)
    submission.assign_attributes(work: params[:work].to_s.first(20_000), submitted_at: Time.current)
    return render json: { ok: false, error: "There's no work to hand in yet." }, status: :unprocessable_entity unless submission.save
    count = @lesson.homework_submissions.where(user: current_user).count
    render json: { ok: true, handed_in: count, complete: count >= @lesson.homework.size, badges: [] }
  end

  # The student finished a step. Their place moves forward one step at a time:
  # a request can't skip ahead, and a quiz step needs an answer on record first.
  def progress
    record = @lesson.class_progresses.find_or_create_by!(user: current_user)
    total = @lesson.steps.size
    wanted = params[:step_index].to_i
    if wanted == record.step_index + 1 && wanted <= total
      finished_step = @lesson.steps[record.step_index]
      if finished_step["kind"] == "quiz" && !record.quiz_first.key?(record.step_index.to_s)
        return render json: { ok: false, step_index: record.step_index, error: "Answer the question first." }, status: :unprocessable_entity
      end
      record.step_index = wanted
    elsif wanted > record.step_index
      return render json: { ok: false, step_index: record.step_index, error: "Steps are finished one at a time." }, status: :unprocessable_entity
    end
    record.hints_used = [ record.hints_used, params[:hints_used].to_i.clamp(0, 200) ].max
    finishing = record.step_index >= total && !record.completed?
    record.completed_at = Time.current if finishing
    record.save!
    badges = finishing ? Badges.award!(current_user) : []
    render json: { ok: true, step_index: record.step_index, completed: record.completed?, badges: badge_payload(badges) }
  end

  # Quiz answers are checked here so the right one never ships with the page.
  def quiz
    number = params[:step].to_i
    step = @lesson.steps[number]
    return head :unprocessable_entity unless step && step["kind"] == "quiz"
    right = step["options"][params[:choice].to_i]&.fetch("right", false) || false
    record = @lesson.class_progresses.find_or_create_by!(user: current_user)
    unless record.quiz_first.key?(number.to_s)
      record.update!(quiz_first: record.quiz_first.merge(number.to_s => right))
    end
    render json: { right: right, explain: (helpers.markdown_inline(step["explain"]) if right) }
  end

  private
    def require_finished_class
      return if performed? || @lesson.completed_by?(current_user)
      respond_to do |format|
        format.html { redirect_to class_lesson_path(@lesson), alert: "Homework opens when you finish the class." }
        format.json { head :forbidden }
      end
    end

    def set_lesson
      @lesson = ClassLesson.find_by!(slug: params[:id])
      return if @lesson.unlocked_for?(current_user)
      respond_to do |format|
        format.html { redirect_to class_lessons_path, alert: "That class opens when #{@lesson.course_code} lesson #{@lesson.lesson_number - 1} is finished." }
        format.json { head :forbidden }
      end
    end
end
