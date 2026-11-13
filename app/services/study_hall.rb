# Friends who opted in, shown as quiet company: what they're on and this week's
# hours. No rankings (Prof. Duarte).
class StudyHall
  Member = Data.define(:user, :course, :hours_this_week, :studying_now)

  def initialize(viewer) = @viewer = viewer

  def members
    User.in_study_hall.where.not(id: @viewer.id).order(:name).map do |u|
      stats = ProgressStats.new(u)
      course = u.course_records.find(&:in_progress?)&.then { |r| "#{r.code} #{r.title}" } ||
               u.enrollments.active.order(updated_at: :desc).first&.course&.title
      Member.new(user: u, course: course, hours_this_week: stats.hours_this_week, studying_now: studying_now?(u))
    end
  end

  private
    def studying_now?(user)
      window = (30.minutes.ago..)
      user.attempts.where(created_at: window).exists? || user.tutor_messages.where(created_at: window).exists? ||
        LessonCompletion.joins(:enrollment).where(enrollments: { user_id: user.id }, created_at: window).exists?
    end
end
