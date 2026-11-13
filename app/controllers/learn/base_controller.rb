module Learn
  # Reading lessons open only for someone who owns the course. The owner of
  # the site opens every course; their progress is kept on an owner-granted
  # enrollment made the first time they open one.
  class BaseController < ApplicationController
    allow_customer_accounts
    before_action :set_enrollment

    private
      def set_enrollment
        @course = Course.find_by!(slug: params[:course_id])
        @enrollment = current_user.enrollments.active.includes(:lesson_completions).find_by(course: @course)
        @enrollment ||= current_user.enrollments.find_or_create_by!(course: @course) { |e| e.source = "admin" } if current_user.admin?
        refuse_course_access(@course.paid? && @course.published? ? store_course_path(@course) : course_path(@course)) unless @enrollment
      end

      def set_lesson
        @lesson = @course.lessons.find_by!(position: params[:lesson_id] || params[:id])
      end
  end
end
