module Portal
  class CertificatesController < ApplicationController
    def show
      course = Course.find_by!(slug: params[:course_id])
      @enrollment = current_user.enrollments.active.includes(:lesson_completions, course: :lessons).find_by!(course: course)
      redirect_to portal_path, alert: "Finish every lesson to unlock your certificate." unless @enrollment.finished?
    end
  end
end
