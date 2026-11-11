require "test_helper"

class PortalTest < ActionDispatch::IntegrationTest
  def import_transcript(user = users(:owner))
    TranscriptImport.call(file_fixture("transcript.md").read, user: user)
  end

  test "the owner syncs the transcript and only the numbers are kept" do
    sign_in_as users(:owner)
    post admin_transcript_path, params: { markdown: file_fixture("transcript.md").read }
    assert_redirected_to portal_path

    snapshot = users(:owner).transcript_snapshot
    assert_equal 12, snapshot.current_day
    assert_equal 41, snapshot.hours_logged
    assert_equal 555, snapshot.stage_hours_target
    assert_equal [ "Gate 1", 30 ], [ snapshot.next_gate_name, snapshot.next_gate_day ]
    assert_equal [ [ "CS 090", 4, "A" ], [ "CS 101", 3, nil ] ], users(:owner).course_records.map { |r| [ r.code, r.lessons_done, r.grade ] }

    stored = [ snapshot, *users(:owner).course_records ].flat_map { |r| r.attributes.values }.join(" ")
    assert_not_includes stored, "SECRET-NOTE-123"

    get portal_path
    assert_response :success
    assert_includes response.body, "CS 101 Intro to Programming"
    assert_select "svg.crest-tree"
    assert_not_includes response.body, "SECRET-NOTE-123"
  end

  test "a file that is not the transcript is refused" do
    sign_in_as users(:owner)
    post admin_transcript_path, params: { markdown: "hello" }
    assert_redirected_to admin_transcript_path
    assert_nil users(:owner).transcript_snapshot
  end

  test "exercises open only after their lesson is taught" do
    import_transcript users(:one)
    sign_in_as users(:one)
    assert exercises(:first).unlocked_for?(users(:one))
    assert_not exercises(:later).unlocked_for?(users(:one))

    get exercises_path
    assert_select "a[href=?]", exercise_path(exercises(:first))
    assert_select "a[href=?]", exercise_path(exercises(:later)), count: 0
    get exercise_path(exercises(:first))
    assert_response :success
    get exercise_path(exercises(:later))
    assert_redirected_to exercises_path
    post exercise_attempts_path(exercises(:later)), params: { code: "x", passed: true }, as: :json
    assert_response :forbidden

    sign_in_as users(:two) # no transcript at all
    get exercise_path(exercises(:first))
    assert_redirected_to exercises_path

    exercises(:later).update!(open_to_all: true)
    get exercise_path(exercises(:later))
    assert_response :success
  end

  test "a passing attempt is recorded and earns badges once" do
    import_transcript users(:one)
    sign_in_as users(:one)
    post exercise_attempts_path(exercises(:first)), params: { code: "puts 4", passed: false, checks_passed: 0, hints_used: 0 }, as: :json
    assert_response :success
    first = response.parsed_body["badges"].map { |b| b["key"] }
    assert_includes first, "first_run"
    assert_not_includes first, "first_pass"
    assert_nil response.parsed_body["next_url"]

    post exercise_attempts_path(exercises(:first)), params: { code: "puts 45", passed: true, checks_passed: 1, hints_used: 0 }, as: :json
    keys = response.parsed_body["badges"].map { |b| b["key"] }
    assert_includes keys, "first_pass"
    assert_includes keys, "no_hints"
    assert exercises(:first).passed_by?(users(:one))

    post exercise_attempts_path(exercises(:first)), params: { code: "puts 45", passed: true, checks_passed: 1, hints_used: 0 }, as: :json
    assert_empty response.parsed_body["badges"]
  end

  test "exercise pages never carry a solution field" do
    assert_not Exercise.column_names.intersect?(%w[solution answer])
  end

  test "study log feeds the streak, with one missed day a week forgiven" do
    user = users(:one)
    today = Time.zone.today
    [ 0, 1, 3, 4 ].each { |ago| user.study_sessions.create!(studied_on: today - ago, minutes: 30) }
    assert_equal 4, ProgressStats.new(user).streak # the gap two days ago is forgiven

    user.study_sessions.where(studied_on: [ today - 3, today - 4 ]).destroy_all
    user.study_sessions.create!(studied_on: today - 12, minutes: 30)
    assert_equal 2, ProgressStats.new(user).streak # a long gap ends it
  end

  test "logging study time from the portal" do
    sign_in_as users(:one)
    post portal_study_sessions_path, params: { study_session: { minutes: 45, note: "Reading" } }
    assert_redirected_to portal_study_sessions_path
    assert_equal 45, users(:one).study_sessions.last.minutes
    post portal_study_sessions_path, params: { study_session: { minutes: 45, studied_on: 2.days.from_now.to_date } }
    assert_equal 1, users(:one).study_sessions.count

    sign_in_as users(:two)
    delete portal_study_session_path(users(:one).study_sessions.last)
    assert_response :not_found
  end

  test "hours and streak badges" do
    user = users(:one)
    7.times { |i| user.study_sessions.create!(studied_on: Time.zone.today - i, minutes: 90) }
    keys = Badges.award!(user).map(&:key)
    assert_includes keys, "streak_7"
    assert_includes keys, "hours_10"
    assert_not_includes keys, "hours_100"
    assert_empty Badges.award!(user)
  end

  test "only listed easter eggs can be claimed" do
    sign_in_as users(:one)
    post portal_egg_path("konami"), as: :json
    assert_response :success
    assert users(:one).user_badges.exists?(key: "konami")
    post portal_egg_path("gate_4"), as: :json
    assert_response :not_found
    assert_not users(:one).user_badges.exists?(key: "gate_4")

    get portal_badges_path
    assert_response :success
  end

  test "study hall is opt-in and shows no one who has not joined" do
    users(:two).study_sessions.create!(studied_on: Time.zone.today, minutes: 60)
    sign_in_as users(:one)
    patch portal_settings_path, params: { user: { share_in_study_hall: "1" } }
    get portal_path
    assert_not_includes response.body, users(:two).first_name

    users(:two).update!(share_in_study_hall: true)
    get portal_path
    assert_includes response.body, users(:two).first_name

    patch portal_settings_path, params: { user: { share_in_study_hall: "0", role: "admin" } }
    assert_not users(:one).reload.admin?
    get portal_path
    assert_not_includes response.body, users(:two).first_name
  end

  test "faculty exercise files parse, with no solutions and known check types" do
    files = Dir[Rails.root.join("db/seeds/exercises/*.md")]
    assert_operator files.size, :>=, 8
    files.each do |path|
      attrs = ExerciseMarkdown.parse(File.read(path))
      exercise = Exercise.new(attrs)
      assert exercise.valid?, "#{path}: #{exercise.errors.full_messages}"
      assert attrs[:checks].any?, path
      assert attrs[:hints].any?, path
    end
  end

  test "visualizer and lab pages render" do
    import_transcript users(:one)
    sign_in_as users(:one)
    get loop_visualizer_path
    assert_response :success
    get exercise_path(exercises(:first))
    assert_select "[data-controller=lab]"
    assert_select ".chips .chip", 1
  end
end
