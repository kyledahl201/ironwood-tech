module Portal
  # Time the portal measures by itself. The page reports seconds the student
  # was active; they are added to today's automatic record for that course and
  # activity. The rules are in StudySession.log_pulse.
  class PulsesController < ApplicationController
    rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, with: -> { head :too_many_requests }

    def create
      activity = StudySession::ACTIVITIES.include?(params[:activity]) ? params[:activity] : "study"
      before = minutes_today
      StudySession.log_pulse(current_user, seconds: params[:seconds], course_code: params[:course_code].to_s.first(40).presence, activity: activity)
      today = minutes_today
      badges = today != before && (before.zero? || (today % 10).zero?) ? Badges.award!(current_user) : []
      label = today.zero? ? "Your time here is logged by itself" : "#{today} min logged today"
      render json: { ok: true, today_minutes: today, today_label: label, badges: badge_payload(badges) }
    end

    private
      def minutes_today = current_user.study_sessions.where(studied_on: Time.zone.today).sum(:minutes)
  end
end
