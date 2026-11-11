class ExercisesController < ApplicationController
  def index
    @exercises = Exercise.ordered.to_a
    @passed = current_user.attempts.where(passed: true).distinct.pluck(:exercise_id).to_set
  end

  def show
    @exercise = Exercise.find_by!(slug: params[:id])
    unless @exercise.unlocked_for?(current_user)
      redirect_to exercises_path, alert: "That exercise opens after #{@exercise.course_code} lesson #{@exercise.lesson_number} is taught." and return
    end
    @list = Exercise.ordered.select { |e| e.course_code == @exercise.course_code }
    @last_attempt = current_user.attempts.where(exercise: @exercise).order(:created_at).last
  end
end
