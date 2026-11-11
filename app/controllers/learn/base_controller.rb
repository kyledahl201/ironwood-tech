module Learn
  class BaseController < ApplicationController
    before_action :set_enrollment

    private
      def set_enrollment
        @course = Course.find_by!(slug: params[:course_id])
        @enrollment = current_user.enrollments.includes(:lesson_completions).find_by(course: @course)
        redirect_to course_path(@course), alert: "Start the course to open its lessons." unless @enrollment
      end

      def set_lesson
        @lesson = @course.lessons.find_by!(position: params[:lesson_id] || params[:id])
      end
  end
end
