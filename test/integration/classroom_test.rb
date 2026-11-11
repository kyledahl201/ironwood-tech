require "test_helper"

class ClassroomTest < ActionDispatch::IntegrationTest
  def lesson(overrides = {})
    @lesson ||= ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("lesson.md").read).merge(overrides))
  end

  def finish(lesson)
    post progress_class_lesson_path(lesson), params: { step_index: lesson.steps.size }, as: :json
  end

  test "a lesson script parses into playable steps without solutions" do
    attrs = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    assert_equal [ "zz-l2", "CS 101", 2, "Prof. Example", 10 ], attrs.values_at(:slug, :course_code, :lesson_number, :professor, :minutes)
    assert_equal %w[teach try mac quiz show try], attrs[:steps].map { |s| s["kind"] }

    try = attrs[:steps][1]
    assert_equal "terminal", try["mode"]
    assert_equal [ "dir_exists", "~/made-up" ], try["checks"][0].values_at("type", "expected")
    assert_equal [ "^mkdir|^md", "you made a folder" ], try["checks"][1].values_at("expected", "label")
    assert_equal [ "First hint.", "Second hint." ], try["hints"]

    assert_equal [ "echo one", "echo two" ], attrs[:steps][2]["run"]
    quiz = attrs[:steps][3]
    assert_includes quiz["text"], "## not a heading"
    assert_equal [ false, true ], quiz["options"].map { |o| o["right"] }
    assert_equal "stack", attrs[:steps][4]["visual"]
    assert_equal "# start here\n", attrs[:steps][5]["starter"]
    assert_equal "hi\n", attrs[:steps][5]["checks"][1]["expected"]

    assert_equal [ "Point one.", "Point two." ], attrs[:study_guide]
    assert_equal [ { "front" => "Front one", "back" => "Back one" } ], attrs[:flashcards]
    assert_equal [ "irb", "x = nil\n", "value_is" ], [ attrs[:homework][0]["mode"], attrs[:homework][0]["starter"], attrs[:homework][0]["checks"][0]["type"] ]
  end

  test "a script with a task that has no checks, or an unknown check, is refused" do
    attrs = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    attrs[:steps][1]["checks"] = []
    attrs[:steps][5]["checks"][0]["type"] = "made_up_check"
    record = ClassLesson.new(attrs)
    assert_not record.valid?
    assert_match(/needs at least one check/, record.errors.full_messages.to_sentence)
    assert_match(/made_up_check/, record.errors.full_messages.to_sentence)
    assert_raises(ClassLessonMarkdown::FormatError) { ClassLessonMarkdown.parse("no front matter") }
  end

  test "every lesson the faculty wrote loads" do
    paths = Dir[Rails.root.join("db/seeds/lessons/*.md")]
    assert paths.any?
    paths.each do |path|
      record = ClassLesson.new(ClassLessonMarkdown.parse(File.read(path)))
      assert record.valid?, "#{File.basename(path)}: #{record.errors.full_messages.to_sentence}"
      (record.steps + record.homework).flat_map { |s| Array(s["checks"]) }.each do |check|
        next unless %w[command_matches output_matches source_matches].include?(check["type"])
        assert Regexp.new(check["expected"]), "#{File.basename(path)}: #{check['expected']}"
      end
    end
  end

  test "class opens after the lesson before it, and Today leads with Start class" do
    lesson
    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_redirected_to class_lessons_path # lesson 1 hasn't happened yet

    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    users(:one).course_records.find_by(code: "CS 101").update!(lessons_done: 1)
    get portal_path
    assert_select "a.btn[href=?]", class_lesson_path(lesson), text: "Start class"
    get class_lessons_path
    assert_select "a[href=?]", class_lesson_path(lesson)

    get class_lesson_path(lesson)
    assert_response :success
    assert_select ".classroom[data-controller=classroom]"
    assert_select "template[data-classroom-target=template]", 6
    assert_select "select[data-classroom-target=mode] option", 3
    assert_select ".mac-runs li", 2
    assert_includes response.body, "Prof. Example"
    assert_includes response.body, "(AI tutor)"
    # The right quiz answer and its explanation stay on the server.
    assert_not_includes response.body, "EXPLAIN-TEXT"
    assert_not_includes response.body, "&quot;right&quot;"
  end

  test "the place in a lesson only moves forward, and finishing counts as taught" do
    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    users(:one).course_records.find_by(code: "CS 101").update!(lessons_done: 1)
    exercise = exercises(:later)
    exercise.update!(course_code: "CS 101", lesson_number: 2)
    sign_in_as users(:one)
    assert_not exercise.unlocked_for?(users(:one))

    post progress_class_lesson_path(lesson), params: { step_index: 3, hints_used: 1 }, as: :json
    assert_equal({ "step_index" => 3, "completed" => false }, response.parsed_body.slice("step_index", "completed"))
    post progress_class_lesson_path(lesson), params: { step_index: 1 }, as: :json
    assert_equal 3, response.parsed_body["step_index"]
    get portal_path
    assert_select "a.btn[href=?]", class_lesson_path(lesson), text: "Resume class"

    finish lesson
    assert response.parsed_body["completed"]
    progress = lesson.progress_for(users(:one))
    assert progress.completed?
    assert_equal 100, progress.percent
    assert exercise.unlocked_for?(users(:one))
    assert_nil ClassLesson.next_for(users(:one))
  end

  test "quiz answers are checked on the server and the first answer is recorded" do
    lesson(lesson_number: 1)
    sign_in_as users(:one)
    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 0 }, as: :json
    assert_equal({ "right" => false, "explain" => nil }, response.parsed_body)
    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 1 }, as: :json
    assert response.parsed_body["right"]
    assert_includes response.parsed_body["explain"], "EXPLAIN-TEXT"

    progress = lesson.progress_for(users(:one))
    assert_equal [ 1, 0 ], [ progress.quiz_total, progress.quiz_right ]
    post quiz_class_lesson_path(lesson), params: { step: 0, choice: 0 }, as: :json
    assert_response :unprocessable_entity
  end

  test "a locked class refuses progress, and signed-out visitors are sent to sign in" do
    lesson
    post progress_class_lesson_path(lesson), params: { step_index: 6 }, as: :json
    assert_nil lesson.progress_for(users(:one))
    sign_in_as users(:one)
    finish lesson
    assert_response :forbidden
    assert_nil lesson.progress_for(users(:one))
  end
end
