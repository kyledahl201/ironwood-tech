# The Programs page: every program, in its tier, with the classes inside it,
# and a page for each program. Anyone can read them. Class content still opens
# only for someone who owns the class (User#can_open?); owning a program gives
# every class in it.
class ProgramsController < ApplicationController
  allow_unauthenticated_access
  allow_customer_accounts

  def index
    @catalog = Catalog.new(current_user)
    @programs = visible_programs.includes(:courses).to_a
    @tours = @catalog.entries.select { |e| e.program == Catalog::START }
    # Classes not placed in a program yet: only for the people who own one.
    @unplaced = @catalog.entries.select { |e| e.program == Catalog::OTHER && e.owned? }
  end

  def show
    @program = visible_programs.find_by!(slug: params[:id])
    @entries = Catalog.new(current_user).for_program(@program)
    @owned = @program.owned_by?(current_user)
    @blocked = Payments.blocked_reason
  end

  private
    # The owner also sees programs that aren't published, to check them first.
    def visible_programs = current_user&.admin? ? Program.ordered : Program.listed
end
