# The classroom. A lesson's checks run in the browser (self-checked practice);
# the server keeps the student's place, answers quiz questions and marks the
# lesson finished. Professors still give the grades.
class ClassLessonsController < ApplicationController
  before_action :set_lesson, except: :index
  rate_limit to: 120, within: 1.minute, by: -> { current_user.id }, with: -> { head :too_many_requests }, only: %i[progress quiz]

  def index
    @lessons = ClassLesson.ordered.to_a
    @progress = current_user.class_progresses.index_by(&:class_lesson_id)
    @next = ClassLesson.next_for(current_user)
  end

  def show
    @progress = @lesson.class_progresses.find_or_create_by!(user: current_user)
    @tools = VisualizersController::TOOLS
  end

  # The student finished a step. Their place only ever moves forward.
  def progress
    record = @lesson.class_progresses.find_or_create_by!(user: current_user)
    total = @lesson.steps.size
    record.step_index = [ record.step_index, params[:step_index].to_i.clamp(0, total) ].max
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
    def set_lesson
      @lesson = ClassLesson.find_by!(slug: params[:id])
      return if @lesson.unlocked_for?(current_user)
      respond_to do |format|
        format.html { redirect_to class_lessons_path, alert: "That class opens when #{@lesson.course_code} lesson #{@lesson.lesson_number - 1} is finished." }
        format.json { head :forbidden }
      end
    end
end
