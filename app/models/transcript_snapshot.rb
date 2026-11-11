# Headline numbers imported from the registrar's TRANSCRIPT.md. Private to its user.
class TranscriptSnapshot < ApplicationRecord
  belongs_to :user

  def next_gate_date = (day_one + (next_gate_day - 1) if day_one && next_gate_day)

  def days_to_next_gate
    next_gate_date && (next_gate_date - Date.current).to_i
  end

  def stage_progress_percent
    return 0 unless stage_hours_target.to_i.positive?
    [ (hours_logged.to_f * 100 / stage_hours_target).round, 100 ].min
  end
end
