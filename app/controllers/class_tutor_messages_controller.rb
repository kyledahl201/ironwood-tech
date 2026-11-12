# A question to the professor from inside the classroom. The reply is written
# off the request and streamed into the tutor panel, as on a reading lesson.
class ClassTutorMessagesController < ApplicationController
  before_action :set_lesson
  rate_limit to: 20, within: 10.minutes, only: :create, by: -> { current_user.id },
             with: -> { refuse "Slow down a little. Try again in a few minutes." }

  def create
    content = params.dig(:tutor_message, :content).to_s.strip
    return refuse("Type a question first.") if content.blank?
    return refuse("You've reached today's #{Tutor.daily_cap} tutor questions for this course. Keep working on the class; your tutor is back tomorrow.") if Tutor.over_cap?(current_user, @lesson.course_code)

    # The snapshot is only sent when the student left "send my workbench" ticked.
    context = params.dig(:tutor_message, :context).to_s.first(16_000).presence
    # Homework opens when the class is finished; a question from there is its own conversation.
    homework = params.dig(:tutor_message, :homework) == "1" && @lesson.completed_by?(current_user)
    @question = current_user.tutor_messages.new(class_lesson: @lesson, role: "user", content: content, context: context, homework: homework)
    return refuse(@question.errors.full_messages.to_sentence) unless @question.save
    @placeholder = current_user.tutor_messages.create!(class_lesson: @lesson, role: "assistant", content: "Thinking…", pending: true, homework: homework)
    TutorReplyJob.perform_later(@placeholder.id)

    respond_to do |format|
      format.turbo_stream { render "learn/tutor_messages/create" }
      format.html { redirect_to class_lesson_path(@lesson) }
    end
  end

  private
    def set_lesson
      @lesson = ClassLesson.find_by!(slug: params[:class_lesson_id])
      head :forbidden unless @lesson.unlocked_for?(current_user)
    end

    def refuse(message)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("tutor-alert", message), status: :unprocessable_entity }
        format.html { redirect_to class_lesson_path(@lesson), alert: message }
      end
    end
end
