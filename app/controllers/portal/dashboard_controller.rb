module Portal
  class DashboardController < ApplicationController
    def show
      @snapshot = current_user.transcript_snapshot
      @records = current_user.course_records.to_a
      enrollments = current_user.enrollments.active.includes(:lesson_completions, course: :lessons).order(updated_at: :desc)
      # A course that ships as a player has no lesson rows; it gets its own card.
      @player_enrollments, @enrollments = enrollments.partition { |e| e.course.player }
      @stats = ProgressStats.new(current_user)
      @tree = CrestTree.for(current_user)
      @today = TodayCard.new(current_user, records: @records, enrollments: @enrollments, stats: @stats)
      @badges = current_user.user_badges.order(earned_at: :desc).limit(6)
      @study_hall = current_user.share_in_study_hall? ? StudyHall.new(current_user).members : []
      @homework_due = ClassLesson.homework_due_for(current_user)
      @new_exercises = Exercise.ordered.select { |e| e.unlocked_for?(current_user) && !e.passed_by?(current_user) }.first(3)
    end
  end
end
