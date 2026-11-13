module Admin
  class EnrollmentsController < BaseController
    def index
      @enrollments = Enrollment.includes(:user, :course).order(created_at: :desc)
    end

    def create
      user = User.find(params[:user_id])
      course = Course.find(params[:course_id])
      enrollment = user.enrollments.find_or_create_by!(course: course) { |e| e.source = "admin" }
      enrollment.reinstate! unless enrollment.active?

      redirect_to admin_user_path(user), notice: "Enrolled #{user.name} in #{course.title}."
    end

    # Ends access. It does not move money: refund in the Stripe dashboard.
    def revoke
      enrollment = Enrollment.find(params[:id])
      enrollment.revoke!("owner")
      redirect_back_or_to admin_enrollments_path, notice: "#{enrollment.user.name} no longer has #{enrollment.course.title}."
    end

    def reinstate
      enrollment = Enrollment.find(params[:id])
      enrollment.reinstate!
      redirect_back_or_to admin_enrollments_path, notice: "#{enrollment.user.name} has #{enrollment.course.title} again."
    end
  end
end
