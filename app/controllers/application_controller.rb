class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user, :brand

  private
    def current_user
      resume_session
      Current.user
    end

    def brand
      Rails.configuration.x.brand
    end

    def require_admin
      redirect_to root_path, alert: "That page is for the owner only." unless current_user&.admin?
    end
end
