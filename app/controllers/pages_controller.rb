class PagesController < ApplicationController
  allow_unauthenticated_access
  allow_customer_accounts

  def home
    return redirect_to home_url_for(current_user) if current_user
    @for_sale = Course.published.sold.exists?
  end

  def privacy; end
  def terms; end
  def refunds; end
end
