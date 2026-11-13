# Checks run in the browser; this records the result and awards badges.
class AttemptsController < ApplicationController
  allow_customer_accounts
  rate_limit to: 60, within: 1.minute, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    exercise = Exercise.find_by!(slug: params[:exercise_id])
    return head :forbidden unless exercise.unlocked_for?(current_user) # owned, and its lesson taught

    attempt = current_user.attempts.create!(
      exercise: exercise, code: params.require(:code).to_s.first(20_000),
      passed: ActiveModel::Type::Boolean.new.cast(params[:passed]),
      checks_passed: params[:checks_passed].to_i, hints_used: params[:hints_used].to_i.clamp(0, 10)
    )
    new_badges = Badges.award!(current_user)
    next_exercise = Exercise.ordered.find { |e| e != exercise && e.unlocked_for?(current_user) && !e.passed_by?(current_user) } if attempt.passed?
    render json: { ok: true, badges: badge_payload(new_badges), next_url: next_exercise && exercise_path(next_exercise), next_title: next_exercise&.title }
  end
end
