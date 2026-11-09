module Admin
  class EnrollmentsController < BaseController
    def create
      user = User.find(params[:user_id])
      course = Course.find(params[:course_id])
      enrollment = user.enrollments.find_or_create_by!(course: course) { |e| e.source = "admin" }
      enrollment.reinstate!(source: "admin") unless enrollment.active?
      redirect_to admin_user_path(user), notice: "Enrolled #{user.name} in #{course.title}."
    end
  end
end
