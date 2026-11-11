module Admin
  class CoursesController < BaseController
    def index
      @courses = Course.order(:position).includes(:lessons, :enrollments)
    end

    def edit
      @course = Course.find_by!(slug: params[:id])
    end

    def update
      @course = Course.find_by!(slug: params[:id])
      if @course.update(course_params)
        redirect_to admin_courses_path, notice: "Saved #{@course.title}."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def course_params
        params.require(:course).permit(:title, :tagline, :description, :published, :level, :tutor_name, :tutor_bio)
      end
  end
end
