# Claiming a gift. The emailed link opens this page; a signed-out visitor
# signs in or makes an account (one that sees the store and what it owns,
# like a buyer's), then presses the button. The token works once, ends after
# Gift::LIFETIME, and the claimer's email doesn't have to match (gifts can be
# forwarded): whoever claims it is recorded on the gift.
class GiftsController < ApplicationController
  allow_unauthenticated_access only: :show
  allow_customer_accounts
  rate_limit to: 20, within: 10.minutes, with: -> { redirect_to root_path, alert: "Too many tries. Please wait a few minutes and open the link again." }
  before_action :set_gift

  def show
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def redeem
    title = @gift.title
    if !@gift.claimable?
      redirect_to gift_claim_path(@token)
    elsif @gift.already_owned_by?(current_user)
      redirect_to gift_claim_path(@token), notice: "You already have #{title}, so this gift is still waiting. You can pass the link on to someone else."
    elsif @gift.redeem!(current_user)
      redirect_to destination, notice: "#{title} is yours#{", with every class in it" if @gift.program?}. Have fun with it."
    else
      redirect_to gift_claim_path(@token), alert: "That gift couldn't be claimed. Please try the link again."
    end
  end

  private
    def set_gift
      @token = params[:token].to_s
      @gift = Gift.find_by_token(@token)
      render :missing, status: :not_found unless @gift
    end

    def destination
      return program_path(@gift.program) if @gift.program?
      course = @gift.course
      return store_course_path(course) if course.paid?
      entry = Catalog.new(current_user).for_course(course)
      entry ? course_path(entry) : home_url_for(current_user)
    end
end
