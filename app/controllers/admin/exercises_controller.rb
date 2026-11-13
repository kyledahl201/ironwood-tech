module Admin
  class ExercisesController < BaseController
    def index
      @exercises = Exercise.ordered
    end

    def update
      exercise = Exercise.find_by!(slug: params[:id])
      exercise.update!(open_to_all: params.dig(:exercise, :open_to_all) == "1")
      redirect_to admin_exercises_path, notice: "#{exercise.title}: #{exercise.open_to_all? ? 'open to everyone who owns the course' : 'opens with its lesson'}."
    end
  end
end
