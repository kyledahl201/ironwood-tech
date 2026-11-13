# Two ways to get an account:
#   * an invite link from the owner (/join?invite=...): the whole portal, free
#   * buying a course (/join?course=...): only while that course can be bought.
#     The account sees the store, what it buys and its own account page.
# With neither, sign-up is closed.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  allow_customer_accounts
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to root_path, alert: "Too many attempts. Try again later." }
  before_action :set_way_in

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(role: :student, customer_only: @invite.nil?))
    User.transaction do
      @user.save!
      @invite&.redeem!(@user)
    end
    start_new_session_for @user
    if @invite
      redirect_to portal_path, notice: "Welcome to #{brand.name}, #{@user.first_name}."
    else
      redirect_to store_course_path(@course), notice: "Your account is ready, #{@user.first_name}. One step left: check the details below and pay."
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private
    def set_way_in
      @invite = Invite.find_usable(params[:invite])
      return if @invite
      @course = Course.published.sold.find_by(slug: params[:course].to_s)
      render :invite_only, status: :forbidden unless @course&.on_sale? && Payments.enabled?
    end

    def user_params
      params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
    end
end
