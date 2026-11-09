module Learn
  class LessonsController < BaseController
    before_action :set_lesson

    def show
      @messages = current_user.tutor_messages.where(lesson: @lesson).chronological
      @tutor_message = TutorMessage.new
    end

    def complete
      @enrollment.lesson_completions.find_or_create_by!(lesson: @lesson)
      if (nxt = @lesson.next_lesson)
        redirect_to learn_lesson_path(@course, nxt)
      else
        redirect_to portal_path, notice: "You finished #{@course.title}."
      end
    end
  end
end
