module Learn
  class BaseController < ApplicationController
    before_action :set_enrollment

    private
      def set_enrollment
        @course = Course.find_by!(slug: params[:course_id])
        @enrollment = current_user.active_enrollments.includes(:lesson_completions).find_by(course: @course)
        @enrollment ||= current_user.enrollments.create!(course: @course, source: "admin") if current_user.admin? && !current_user.enrollments.exists?(course: @course)
        redirect_to course_path(@course), alert: "Enroll to open the lessons." unless @enrollment
      end

      def set_lesson
        @lesson = @course.lessons.find_by!(position: params[:lesson_id] || params[:id])
      end
  end
end
