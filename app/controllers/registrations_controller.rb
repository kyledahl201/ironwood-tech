# Three ways to get an account:
#   * an invite link from the owner (/join?invite=...): the whole portal. Its
#     courses still open only once they're owned.
#   * buying a course (/join?course=...) or a program (/join?program=...):
#     only while it can be bought.
#     The account sees the store, what it owns and its own account page.
#   * claiming a gift (/join?gift=...): only while the gift can be claimed.
#     The same kind of account as a buyer's.
# With none of them, sign-up is closed.
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
    elsif @gift
      redirect_to gift_claim_path(params[:gift]), notice: "Your account is ready, #{@user.first_name}. One step left: press the button to get your gift."
    else
      redirect_to @product_path, notice: "Your account is ready, #{@user.first_name}. One step left: check the details below and pay."
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private
    def set_way_in
      @invite = Invite.find_usable(params[:invite])
      return if @invite
      @gift = Gift.find_by_token(params[:gift])
      return if @gift&.claimable?
      @gift = nil
      if params[:program].present?
        @product = Program.listed.find_by(slug: params[:program].to_s)
        @product_path = @product && program_path(@product)
        @join_path = @product && registration_path(program: @product.slug)
      else
        @product = Course.published.sold.find_by(slug: params[:course].to_s)
        @product_path = @product && store_course_path(@product)
        @join_path = @product && registration_path(course: @product.slug)
      end
      render :invite_only, status: :forbidden unless @product&.on_sale? && Payments.enabled?
    end

    def user_params
      params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
    end
end
