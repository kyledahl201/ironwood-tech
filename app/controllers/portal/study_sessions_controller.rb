module Portal
  # The study log. Time in class, on the study page, on homework and in the
  # code lab is logged by itself (Portal::PulsesController). This is where it
  # shows up, and where time spent away from the portal is added with one tap.
  class StudySessionsController < ApplicationController
    def index
      @today = Time.zone.today
      @sessions = current_user.study_sessions.logged.recent.limit(150).to_a
      @days = @sessions.group_by(&:studied_on)
      @today_minutes = @days[@today].to_a.sum(&:minutes)
      @codes = current_user.course_records.map(&:code)
      @default_code = current_user.course_records.find(&:in_progress?)&.code
    end

    def create
      attrs = params.require(:study_session).permit(:studied_on, :minutes, :course_code, :note, :activity)
      @session = current_user.study_sessions.new(attrs.merge(source: "manual"))
      @session.studied_on = Time.zone.yesterday if params[:when] == "yesterday"
      @session.studied_on ||= Time.zone.today
      @session.activity = nil unless StudySession::ACTIVITIES.include?(@session.activity)
      if @session.save
        new_badges = Badges.award!(current_user)
        respond_to do |format|
          format.json { render json: { ok: true, badges: badge_payload(new_badges) } }
          format.html do
            announce_badges new_badges
            redirect_back fallback_location: portal_study_sessions_path, notice: "Added #{@session.minutes} minutes#{": #{@session.label}" if @session.activity}#{', for yesterday' if @session.studied_on == Time.zone.yesterday}."
          end
        end
      else
        respond_to do |format|
          format.json { render json: { ok: false, errors: @session.errors.full_messages }, status: :unprocessable_entity }
          format.html { redirect_to portal_study_sessions_path, alert: @session.errors.full_messages.to_sentence }
        end
      end
    end

    def destroy
      current_user.study_sessions.find(params[:id]).destroy
      redirect_to portal_study_sessions_path, notice: "Removed."
    end
  end
end
