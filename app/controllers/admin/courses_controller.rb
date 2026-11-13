module Admin
  class CoursesController < BaseController
    def index
      @courses = Course.order(:position).includes(:lessons, :enrollments, :program)
    end

    def edit
      @course = Course.find_by!(slug: params[:id])
      @programs = Program.ordered
    end

    def update
      @course = Course.find_by!(slug: params[:id])
      if @course.update(course_params)
        redirect_to admin_courses_path, notice: "Saved #{@course.title}."
      else
        @programs = Program.ordered
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def course_params
        permitted = %i[title tagline description published level tutor_name tutor_bio program_id]
        # Only a sold course has a price. Whether a course is sold is set in db/seeds.rb.
        permitted << :price_cents if @course.paid?
        params.require(:course).permit(*permitted)
      end
  end
end
