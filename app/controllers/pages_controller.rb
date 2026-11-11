class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    redirect_to portal_path if current_user
  end

  def privacy; end
end
