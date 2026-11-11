module Admin
  class DashboardController < BaseController
    def show
      @counts = {
        students: User.count, open_invites: Invite.open.count, enrollments: Enrollment.count,
        exercises: Exercise.count, attempts: Attempt.count, sessions: StudySession.count
      }
      @snapshot = current_user.transcript_snapshot
    end
  end
end
