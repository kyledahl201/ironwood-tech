# Sends a course's player page (db/course_players/<slug>/, never public/) and
# its practice files to the owner and to students with an active enrollment.
# Everyone else is sent to the course's page; signed-out visitors to sign in.
class CoursePlayersController < ApplicationController
  allow_customer_accounts
  before_action :set_player

  def show
    no_store
    render html: @player.html(back_url: back_path, back_label: "Back to #{brand.name}").html_safe, layout: false
  end

  def downloads
    return head :not_found unless @player.downloads?
    no_store
    send_data @player.download_zip, filename: @player.download_filename, type: "application/zip", disposition: "attachment"
  end

  private
    def set_player
      @course = Course.find_by!(slug: params[:course_id])
      @player = @course.player or raise ActiveRecord::RecordNotFound
      return if current_user.can_open?(@course)
      if @course.paid? && @course.published?
        redirect_to store_course_path(@course), alert: "#{@course.title} opens once you've bought it."
      else
        redirect_to home_url_for(current_user), alert: "That course isn't open to you."
      end
    end

    def back_path = @course.paid? ? store_course_path(@course) : course_path(@course)

    # Paid content: keep it out of shared caches and search engines.
    def no_store
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end
end
