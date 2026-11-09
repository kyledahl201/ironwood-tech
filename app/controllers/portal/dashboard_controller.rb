module Portal
  class DashboardController < ApplicationController
    def show
      @enrollments = current_user.active_enrollments.includes(:lesson_completions, course: :lessons).order(created_at: :desc)
    end
  end
end
