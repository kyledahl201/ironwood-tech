# Buying a whole program. The same rules as a course (CheckoutsController):
# the buyer goes to Stripe Checkout, and the program is theirs only after
# Stripe confirms payment (this success page reads the session back, and the
# webhook does the same). A program that is Coming, or has no price, can't be
# bought.
class ProgramCheckoutsController < ApplicationController
  allow_customer_accounts
  before_action :set_program

  def create
    gift_to = gift_recipient
    back = program_path(@program)
    if gift_to == :invalid
      redirect_to back, alert: "Please type the email address of the person the gift is for."
    elsif gift_to && !EmailDelivery.enabled?
      redirect_to back, alert: "Gifts can't be sent just yet, so nothing was charged."
    elsif !gift_to && current_user.holds_program?(@program)
      redirect_to back, notice: "You already have #{@program.title}."
    elsif !@program.on_sale?
      redirect_to back, alert: "#{@program.title} can't be bought yet."
    elsif !Payments.enabled?
      redirect_to back, alert: "Checkout isn't open yet, so nothing was charged."
    elsif params[:accept_terms] != "1"
      redirect_to back, alert: "Please tick the box to say you're 18 or older and you agree to the Terms of Sale and Privacy Policy."
    else
      checkout = Payments.create_session(
        program: @program, user: current_user, terms_accepted_at: Time.current, gift_to: gift_to,
        success_url: checkout_success_program_url(@program) + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: program_url(@program)
      )
      redirect_to checkout.url, allow_other_host: true, status: :see_other
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("[payments] #{e.class}: #{e.message}")
    redirect_to program_path(@program), alert: "Checkout couldn't be opened just now, so nothing was charged. Please try again in a few minutes."
  end

  def success
    result = Payments.fulfill(params[:session_id].to_s, expected_user: current_user)
    if result.is_a?(Gift) && result.program == @program && !result.revoked?
      redirect_to program_path(@program), notice: "Payment received. We #{result.emailed_at ? "emailed #{result.recipient_email} a link to get #{@program.title}" : "will email #{result.recipient_email} a link to get #{@program.title}"}."
    elsif result.is_a?(ProgramEnrollment) && result.active? && result.program == @program
      redirect_to program_path(@program), notice: "Payment received. #{@program.title} is yours, with every class in it."
    else
      redirect_to program_path(@program), alert: "We couldn't confirm that payment yet. If you were charged, email #{brand.contact_email}."
    end
  end

  private
    # nil when it's not a gift, the recipient's email, or :invalid.
    def gift_recipient
      return nil unless params[:gift] == "1"
      email = params[:gift_email].to_s.strip.downcase
      email.match?(URI::MailTo::EMAIL_REGEXP) && email.length <= 254 ? email : :invalid
    end

    def set_program
      @program = Program.listed.find_by!(slug: params[:id])
    end
end
