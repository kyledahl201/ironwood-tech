# The code lab. An exercise belongs to a course (its course code) and opens
# only for someone who owns that course.
class ExercisesController < ApplicationController
  allow_customer_accounts

  def index
    @exercises = Exercise.ordered.select { |e| e.owned_by?(current_user) }
    @passed = current_user.attempts.where(passed: true).distinct.pluck(:exercise_id).to_set
  end

  def show
    @exercise = Exercise.find_by!(slug: params[:id])
    return refuse_course_access(exercises_path) unless @exercise.owned_by?(current_user)
    unless @exercise.unlocked_for?(current_user)
      redirect_to exercises_path, alert: "That exercise opens after #{@exercise.course_code} lesson #{@exercise.lesson_number} is taught." and return
    end
    @list = Exercise.ordered.select { |e| e.course_code == @exercise.course_code }
    @last_attempt = current_user.attempts.where(exercise: @exercise).order(:created_at).last
  end
end
