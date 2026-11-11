module Portal
  # Time the portal measures by itself. The page reports seconds the student
  # was active; they are added to today's automatic record for that course and
  # activity. A record can't grow faster than the clock on the wall.
  class PulsesController < ApplicationController
    rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, with: -> { head :too_many_requests }

    def create
      activity = StudySession::ACTIVITIES.include?(params[:activity]) ? params[:activity] : "study"
      session = current_user.study_sessions.auto.find_or_initialize_by(studied_on: Time.zone.today, course_code: params[:course_code].to_s.first(40).presence, activity: activity)
      before = session.minutes.to_i
      session.add_seconds(params[:seconds].to_i)
      session.save!
      badges = session.minutes != before && (before.zero? || (session.minutes % 10).zero?) ? Badges.award!(current_user) : []
      today = current_user.study_sessions.where(studied_on: Time.zone.today).sum(:minutes)
      render json: { ok: true, minutes: session.minutes, today_minutes: today, today_label: "#{today} min logged today", badges: badge_payload(badges) }
    end
  end
end
