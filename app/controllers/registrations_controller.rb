# Accounts are invite-only: the owner sends a /join?invite=... link.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to root_path, alert: "Too many attempts. Try again later." }
  before_action :set_invite

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(role: :student))
    User.transaction do
      @user.save!
      @invite.redeem!(@user)
    end
    start_new_session_for @user
    redirect_to portal_path, notice: "Welcome to #{brand.name}, #{@user.first_name}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private
    def set_invite
      @invite = Invite.find_usable(params[:invite])
      render :invite_only, status: :forbidden unless @invite
    end

    def user_params
      params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
    end
end
