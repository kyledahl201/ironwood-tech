module Admin
  class DashboardController < BaseController
    def show
      @counts = {
        students: User.student.count,
        enrollments: Enrollment.count,
        paid: Enrollment.where(source: "stripe").count,
        revenue_cents: Enrollment.where(source: "stripe").sum(:amount_cents),
        new_leads: Lead.where(status: "new").count,
        subscribers: Lead.where(kind: "newsletter").count
      }
      @leads = Lead.recent.limit(5)
      @enrollments = Enrollment.includes(:user, :course).order(created_at: :desc).limit(5)
    end
  end
end
