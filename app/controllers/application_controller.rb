class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  # After Authentication's own check: an account made by buying a course sees
  # only the store, what it bought and its account page.
  before_action :require_portal_member

  helper_method :current_user, :brand

  # For the few pages a course buyer's account may open.
  def self.allow_customer_accounts(**options)
    skip_before_action :require_portal_member, **options
  end

  private
    def require_portal_member
      user = current_user
      redirect_to store_path if user && !user.portal_member?
    end

    def current_user
      resume_session
      Current.user
    end

    def brand
      Rails.configuration.x.brand
    end

    # Course content someone doesn't own (User#can_open?). JSON requests get a
    # plain 403; pages go to the course's page, which says how to get access.
    def refuse_course_access(back = programs_path)
      respond_to do |format|
        format.html { redirect_to back, alert: "That class isn't yours yet. Classes here open once you own them: get the program it's in, or ask the owner for access." }
        format.any { head :forbidden }
      end
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
