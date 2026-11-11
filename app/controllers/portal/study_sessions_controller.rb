module Portal
  class StudySessionsController < ApplicationController
    def index
      @sessions = current_user.study_sessions.recent.limit(100)
      @session = current_user.study_sessions.new(studied_on: Time.zone.today, minutes: 30)
      @codes = current_user.course_records.map(&:code) + current_user.courses.map(&:title)
    end

    def create
      @session = current_user.study_sessions.new(params.require(:study_session).permit(:studied_on, :minutes, :course_code, :note))
      @session.studied_on ||= Time.zone.today
      if @session.save
        new_badges = Badges.award!(current_user)
        respond_to do |format|
          format.json { render json: { ok: true, badges: badge_payload(new_badges) } }
          format.html do
            announce_badges new_badges
            redirect_back fallback_location: portal_study_sessions_path, notice: "Session logged: #{@session.minutes} minutes."
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
