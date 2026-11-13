# Numbers for the dashboard: study heatmap, forgiving streak, weekly hours.
# Activity comes from logged study time plus real work in the portal
# (lab attempts, finished lessons, tutor questions).
class ProgressStats
  HEATMAP_WEEKS = 26

  def initialize(user, today: Time.zone.today)
    @user, @today = user, today
  end

  def minutes_by_day
    @minutes_by_day ||= @user.study_sessions.logged.where(studied_on: heatmap_start..@today).group(:studied_on).sum(:minutes)
  end

  def active_days
    @active_days ||= begin
      days = minutes_by_day.keys.to_set
      range = heatmap_start.beginning_of_day..@today.end_of_day
      [ @user.attempts.where(created_at: range).pluck(:created_at),
        LessonCompletion.joins(:enrollment).where(enrollments: { user_id: @user.id }, created_at: range).pluck(:created_at),
        @user.tutor_messages.where(role: "user", created_at: range).pluck(:created_at) ].flatten.each { |t| days << t.in_time_zone.to_date }
      days
    end
  end

  def heatmap_start = (@today - (HEATMAP_WEEKS * 7 - 1)).beginning_of_week(:sunday)

  # Weeks of [date, level 0..4] for the heatmap grid.
  def heatmap
    (heatmap_start..@today).each_slice(7).map do |week|
      week.map { |d| [ d, level_for(d) ] }
    end
  end

  def level_for(day)
    minutes = minutes_by_day[day].to_i
    return 0 if minutes.zero? && !active_days.include?(day)
    case minutes
    when 0..29 then 1
    when 30..89 then 2
    when 90..179 then 3
    else 4
    end
  end

  # Consecutive study days, forgiving one missed day per week (Mon-Sun), so a
  # single bad day doesn't wipe it out. Today doesn't count against you yet.
  def streak
    count = 0
    graced = Set.new
    day = active_days.include?(@today) ? @today : @today - 1
    loop do
      if active_days.include?(day)
        count += 1
      else
        week = day.beginning_of_week
        break if graced.include?(week) || count.zero?
        graced << week
      end
      day -= 1
      break if day < heatmap_start
    end
    count
  end

  def minutes_this_week
    @user.study_sessions.where(studied_on: @today.beginning_of_week..@today).sum(:minutes)
  end

  def hours_this_week = (minutes_this_week / 60.0).round(1)

  def total_hours
    logged = @user.study_sessions.sum(:minutes) / 60.0
    [ logged, @user.transcript_snapshot&.hours_logged.to_f ].max.round(2)
  end

  def days_away
    last = active_days.select { |d| d < @today }.max
    last ? (@today - last).to_i : nil
  end
end
