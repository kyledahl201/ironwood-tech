# The public sales pages: the sold courses, and one page for each. Anyone can
# read them; buying needs an account (CheckoutsController).
class StoreController < ApplicationController
  allow_unauthenticated_access
  allow_customer_accounts

  def index
    @courses = Course.published.sold.to_a
    @owned = current_user ? current_user.enrollments.active.where(course: @courses).pluck(:course_id).to_set : Set.new
  end

  def show
    # The owner can look at a sold course's page before publishing it.
    @course = (current_user&.admin? ? Course.sold : Course.published.sold).find_by!(slug: params[:id])
    @can_open = current_user&.can_open?(@course)
    @blocked = Payments.blocked_reason
  end
end
