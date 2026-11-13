# Buying a sold course. The buyer is sent to Stripe Checkout; the enrollment is
# created only after Stripe confirms payment (the success page reads the
# session back from Stripe, and the webhook does the same job if the buyer
# never comes back). Never from the browser's redirect alone.
class CheckoutsController < ApplicationController
  allow_customer_accounts
  before_action :set_course

  def create
    gift_to = gift_recipient
    if gift_to == :invalid
      redirect_to store_course_path(@course), alert: "Please type the email address of the person the gift is for."
    elsif gift_to && !EmailDelivery.enabled?
      redirect_to store_course_path(@course), alert: "Gifts can't be sent just yet, so nothing was charged."
    elsif !gift_to && current_user.enrolled_in?(@course)
      redirect_to store_course_path(@course), notice: "You already have #{@course.title}."
    elsif !@course.on_sale?
      redirect_to store_course_path(@course), alert: "#{@course.title} isn't on sale yet."
    elsif !Payments.enabled?
      redirect_to store_course_path(@course), alert: "Checkout isn't open yet, so nothing was charged."
    elsif params[:accept_terms] != "1"
      redirect_to store_course_path(@course), alert: "Please tick the box to say you're 18 or older and you agree to the Terms of Sale and Privacy Policy."
    else
      checkout = Payments.create_session(
        course: @course, user: current_user, terms_accepted_at: Time.current, gift_to: gift_to,
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
    result = Payments.fulfill(params[:session_id].to_s, expected_user: current_user)
    if result.is_a?(Gift) && result.course == @course && !result.revoked?
      redirect_to store_course_path(@course), notice: gift_notice(result)
    elsif result.is_a?(Enrollment) && result.active? && result.course == @course
      redirect_to store_course_path(@course), notice: "Payment received. #{@course.title} is yours."
    else
      redirect_to store_course_path(@course), alert: "We couldn't confirm that payment yet. If you were charged, email #{brand.contact_email}."
    end
  end

  private
    # nil when it's not a gift, the recipient's email, or :invalid.
    def gift_recipient
      return nil unless params[:gift] == "1"
      email = params[:gift_email].to_s.strip.downcase
      email.match?(URI::MailTo::EMAIL_REGEXP) && email.length <= 254 ? email : :invalid
    end

    def gift_notice(gift)
      if gift.emailed_at
        "Payment received. We emailed #{gift.recipient_email} a link to get #{@course.title}. The link works for #{Gift::LIFETIME.inspect}."
      else
        "Payment received. The email to #{gift.recipient_email} didn't go out yet; we'll send it. Questions? Email #{brand.contact_email}."
      end
    end

    def set_course
      @course = Course.published.sold.find_by!(slug: params[:id])
    end
end
