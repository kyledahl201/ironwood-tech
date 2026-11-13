# The transcript logs hours like 0.75. One decimal place stored it as 0.8.
# Two places keep it as written. Values already stored stay rounded until the
# transcript is synced again (Owner > Transcript).
class KeepTranscriptHoursToTwoPlaces < ActiveRecord::Migration[8.1]
  def up
    change_column :transcript_snapshots, :hours_logged, :decimal, precision: 8, scale: 2, default: "0.0", null: false
    change_column :course_records, :hours_logged, :decimal, precision: 8, scale: 2, default: "0.0", null: false
  end

  def down
    change_column :transcript_snapshots, :hours_logged, :decimal, precision: 7, scale: 1, default: "0.0", null: false
    change_column :course_records, :hours_logged, :decimal, precision: 7, scale: 1, default: "0.0", null: false
  end
end
