# Buying a sold course. The buyer is sent to Stripe Checkout; the enrollment is
# created only after Stripe confirms payment (the success page reads the
# session back from Stripe, and the webhook does the same job if the buyer
# never comes back). Never from the browser's redirect alone.
class CheckoutsController < ApplicationController
  allow_customer_accounts
  before_action :set_course

  def create
    if current_user.enrolled_in?(@course)
      redirect_to store_course_path(@course), notice: "You already have #{@course.title}."
    elsif !@course.on_sale?
      redirect_to store_course_path(@course), alert: "#{@course.title} isn't on sale yet."
    elsif !Payments.enabled?
      redirect_to store_course_path(@course), alert: "Checkout isn't open yet, so nothing was charged."
    elsif params[:accept_terms] != "1"
      redirect_to store_course_path(@course), alert: "Please tick the box to say you're 18 or older and you agree to the Terms of Sale and Privacy Policy."
    else
      checkout = Payments.create_session(
        course: @course, user: current_user, terms_accepted_at: Time.current,
        success_url: store_checkout_success_url(@course) + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: store_course_url(@course)
      )
      redirect_to checkout.url, allow_other_host: true, status: :see_other
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("[payments] #{e.class}: #{e.message}")
    redirect_to store_course_path(@course), alert: "Checkout couldn't be opened just now, so nothing was charged. Please try again in a few minutes."
  end

  def success
    enrollment = Payments.fulfill(params[:session_id].to_s, expected_user: current_user)
    if enrollment&.active? && enrollment.course == @course
      redirect_to store_course_path(@course), notice: "Payment received. #{@course.title} is yours."
    else
      redirect_to store_course_path(@course), alert: "We couldn't confirm that payment yet. If you were charged, email #{brand.contact_email}."
    end
  end

  private
    def set_course
      @course = Course.published.sold.find_by!(slug: params[:id])
    end
end
