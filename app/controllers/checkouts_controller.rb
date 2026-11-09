# Free courses enroll immediately. Paid courses go to Stripe Checkout; the
# enrollment is created only after Stripe confirms payment (success page or
# webhook), never from a client-side redirect alone.
class CheckoutsController < ApplicationController
  before_action :set_course

  def create
    if current_user.enrolled_in?(@course)
      redirect_to learn_lesson_path(@course, 1) and return
    end

    if !@course.on_sale?
      redirect_to course_path(@course), alert: "#{@course.title} isn't on sale yet. Join the newsletter to hear when it opens."
    elsif @course.free?
      enrollment = current_user.enrollments.find_or_create_by!(course: @course) { |e| e.source = "free" }
      enrollment.reinstate!(source: "free") unless enrollment.active?
      redirect_to learn_lesson_path(@course, 1), notice: "You're enrolled. Welcome to #{@course.title}."
    elsif Payments.enabled? && params[:accept_terms] != "1"
      redirect_to course_path(@course), alert: "Please confirm you've read the terms and refund policy."
    elsif Payments.enabled?
      session = Payments.checkout_session(
        terms_accepted_at: Time.current,
        course: @course, user: current_user,
        success_url: course_checkout_success_url(@course) + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: course_url(@course)
      )
      redirect_to session.url, allow_other_host: true, status: :see_other
    else
      redirect_to course_path(@course), alert: "Checkout isn't open yet. Join the newsletter to hear when it is."
    end
  end

  def success
    enrollment = Payments.fulfill(params[:session_id].to_s, expected_user: current_user)
    if enrollment
      redirect_to learn_lesson_path(enrollment.course, 1), notice: "Payment received. You're enrolled."
    else
      redirect_to course_path(@course), alert: "We couldn't confirm that payment yet. If you were charged, email #{brand.contact_email}."
    end
  end

  private
    def set_course
      @course = Course.published.find_by!(slug: params[:course_id])
    end
end
