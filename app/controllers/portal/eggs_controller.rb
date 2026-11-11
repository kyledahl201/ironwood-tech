module Portal
  # Easter eggs found in the browser (only the ones listed in Badges::EGGS).
  class EggsController < ApplicationController
    def create
      key = params[:key].to_s
      return head :not_found unless Badges::EGGS.include?(key)
      new_badges = Badges.award!(current_user, extra: [ key ])
      render json: { badges: badge_payload(new_badges) }
    end
  end
end
