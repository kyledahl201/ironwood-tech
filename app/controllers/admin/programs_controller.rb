module Admin
  # The owner's list of programs: their tier, classes, price and who holds
  # them. Tiers and the program list itself live in config/program_catalog.yml;
  # text, price and the published switch are edited here.
  class ProgramsController < BaseController
    def index
      @programs = Program.ordered.includes(:courses, :program_enrollments)
    end

    def edit
      @program = Program.find_by!(slug: params[:id])
    end

    def update
      @program = Program.find_by!(slug: params[:id])
      if @program.update(params.require(:program).permit(:title, :tagline, :description, :price_cents, :published))
        redirect_to admin_programs_path, notice: "Saved #{@program.title}."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
