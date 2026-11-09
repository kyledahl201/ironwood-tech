class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @courses = Course.published.limit(3)
    @posts = Post.published.limit(3)
    @lead = Lead.new(kind: "newsletter")
  end

  def about; end
  def faq; end
  def refunds; end
  def terms; end
  def privacy; end
end
