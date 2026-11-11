module Learn
  class TutorMessagesController < BaseController
    before_action :set_lesson
    rate_limit to: 20, within: 10.minutes, only: :create, by: -> { current_user.id },
               with: -> { redirect_to learn_lesson_path(params[:course_id], params[:lesson_id], anchor: "tutor"), alert: "Slow down a little. Try again in a few minutes." }

    def create
      content = params.dig(:tutor_message, :content).to_s.strip
      if content.blank?
        redirect_to learn_lesson_path(@course, @lesson, anchor: "tutor"), alert: "Type a question first." and return
      end
      if Tutor.over_cap?(current_user, @course)
        redirect_to learn_lesson_path(@course, @lesson, anchor: "tutor"),
                    alert: "You've reached today's #{Tutor.daily_cap(@course)} tutor questions. Keep working on the lesson; your tutor is back tomorrow." and return
      end

      @question = current_user.tutor_messages.create!(lesson: @lesson, role: "user", content: content)
      @placeholder = current_user.tutor_messages.create!(lesson: @lesson, role: "assistant", content: "Thinking…", pending: true)
      TutorReplyJob.perform_later(@placeholder.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to learn_lesson_path(@course, @lesson, anchor: "tutor") }
      end
    end
  end
end
