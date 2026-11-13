module Admin
  # Giving a whole program to a student, and ending it. Holding a program
  # gives an enrollment in each of its classes (ProgramEnrollment#fan_out!).
  class ProgramEnrollmentsController < BaseController
    def create
      user = User.find(params[:user_id])
      program = Program.find(params[:program_id])
      return redirect_to admin_user_path(user), alert: "#{program.title} has no classes yet, so there's nothing to give." if program.coming?
      ProgramEnrollment.grant!(user: user, program: program, source: "admin", gift: nil)
      redirect_to admin_user_path(user), notice: "#{user.name} now has #{program.title}, with every class in it."
    end

    # Ends the program and the class access it gave. No money moves: refund in Stripe.
    def revoke
      pe = ProgramEnrollment.find(params[:id])
      pe.revoke!("owner")
      redirect_to admin_user_path(pe.user), notice: "#{pe.user.name} no longer has #{pe.program.title}."
    end

    def reinstate
      pe = ProgramEnrollment.find(params[:id])
      pe.reinstate!
      redirect_to admin_user_path(pe.user), notice: "#{pe.user.name} has #{pe.program.title} again."
    end
  end
end
