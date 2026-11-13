module Portal
  # A student's own name, email and password. Every change needs the current
  # password, so a browser left signed in can't be used to take the account over.
  class AccountsController < ApplicationController
    allow_customer_accounts
    rate_limit to: 10, within: 10.minutes, only: :update, with: -> { redirect_to portal_account_path, alert: "Too many attempts. Try again in a few minutes." }

    def show
      @user = current_user
    end

    def update
      # A separate copy, so a rejected change never shows in the page header.
      @user = User.find(current_user.id)
      changes = account_params
      # Text in either box means a new password is wanted, so a lone "repeat" can't be dropped quietly.
      new_password = changes[:password].present? || changes[:password_confirmation].present?
      changes = changes.except(:password, :password_confirmation) unless new_password

      unless @user.authenticate(params.dig(:user, :current_password).to_s)
        @user.assign_attributes(changes.except(:password, :password_confirmation))
        @user.errors.add(:base, "Your current password isn't right, so nothing was changed.")
        return render :show, status: :unprocessable_entity
      end

      @user.assign_attributes(changes)
      new_email = @user.email_address_changed?
      if new_password && changes[:password].blank?
        @user.errors.add(:password, "can't be blank when you've typed it in the repeat box")
        return render :show, status: :unprocessable_entity
      end

      if @user.save
        # A new password signs out every other browser; this one stays signed in.
        @user.sessions.where.not(id: Current.session.id).destroy_all if new_password
        said = [ "Saved." ]
        said << "You now sign in as #{@user.email_address}." if new_email
        said << "Your password is changed, and other devices have been signed out." if new_password
        redirect_to portal_account_path, notice: said.join(" ")
      else
        render :show, status: :unprocessable_entity
      end
    end

    private
      def account_params
        params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
      end
  end
end
