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

    # New badges show as a celebration on the next page.
    def announce_badges(badges)
      flash[:badges] = badges.map(&:key) if badges.any?
    end

    # Badge details for pages that celebrate without reloading.
    def badge_payload(badges)
      badges.filter_map do |b|
        d = b.definition or next
        { key: d.key, name: d.name, description: d.description, image: helpers.image_path(helpers.badge_file(d.key)) }
      end
    end
end
