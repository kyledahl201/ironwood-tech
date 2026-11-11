module Portal
  class BadgesController < ApplicationController
    def index
      @earned = current_user.user_badges.index_by(&:key)
    end
  end
end
