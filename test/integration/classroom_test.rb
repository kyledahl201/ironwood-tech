require "test_helper"

class ClassroomTest < ActionDispatch::IntegrationTest
  def lesson(overrides = {})
    @lesson ||= ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("lesson.md").read).merge(overrides))
  end

  # Works through a lesson the way the classroom does: one step per request,
  # answering each quiz question first.
  def finish(lesson, from: 0)
    (from...lesson.steps.size).each do |i|
      post quiz_class_lesson_path(lesson), params: { step: i, choice: 1 }, as: :json if lesson.steps[i]["kind"] == "quiz"
      post progress_class_lesson_path(lesson), params: { step_index: i + 1 }, as: :json
    end
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

    (1..3).each { |n| post progress_class_lesson_path(lesson), params: { step_index: n, hints_used: 1 }, as: :json }
    assert_equal({ "step_index" => 3, "completed" => false }, response.parsed_body.slice("step_index", "completed"))
    post progress_class_lesson_path(lesson), params: { step_index: 1 }, as: :json
    assert_equal 3, response.parsed_body["step_index"]
    get portal_path
    assert_select "a.btn[href=?]", class_lesson_path(lesson), text: "Resume class"

    finish lesson, from: 3
    assert response.parsed_body["completed"]
    progress = lesson.progress_for(users(:one))
    assert progress.completed?
    assert_equal 100, progress.percent
    assert exercise.unlocked_for?(users(:one))
    assert_nil ClassLesson.next_for(users(:one))
  end

  test "one request can't finish a lesson or skip ahead" do
    lesson(lesson_number: 1)
    sign_in_as users(:one)
    [ lesson.steps.size, 2 ].each do |jump|
      post progress_class_lesson_path(lesson), params: { step_index: jump }, as: :json
      assert_response :unprocessable_entity
      assert_equal 0, response.parsed_body["step_index"]
    end
    progress = lesson.progress_for(users(:one))
    assert_not progress.completed?
    assert_equal 0, progress.step_index
    assert_empty users(:one).user_badges
  end

  test "a quiz step can't be passed until the question has an answer on record" do
    lesson(lesson_number: 1)
    sign_in_as users(:one)
    (1..3).each { |n| post progress_class_lesson_path(lesson), params: { step_index: n }, as: :json }
    post progress_class_lesson_path(lesson), params: { step_index: 4 }, as: :json # step 3 is the quiz
    assert_response :unprocessable_entity
    assert_equal 3, lesson.progress_for(users(:one)).step_index

    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 0 }, as: :json
    post progress_class_lesson_path(lesson), params: { step_index: 4 }, as: :json
    assert_response :success
    assert_equal 4, lesson.progress_for(users(:one)).step_index
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
    post progress_class_lesson_path(lesson), params: { step_index: 1 }, as: :json
    assert_response :forbidden
    assert_nil lesson.progress_for(users(:one))
  end

  test "the study page has the guide and flashcards, and holds questions back until class is finished" do
    lesson(lesson_number: 1)
    sign_in_as users(:one)
    get study_class_lesson_path(lesson)
    assert_response :success
    assert_select ".guide-list li", 2
    assert_select "[data-study-target=source]", 1
    assert_select ".study-question", 0
    assert_includes response.body, "Homework opens when you finish the class."
    assert_not_includes response.body, "SECRET-RIGHT"

    get homework_class_lesson_path(lesson)
    assert_redirected_to class_lesson_path(lesson)
    post homework_class_lesson_path(lesson), params: { task_index: 0, work: "x = 5" }, as: :json
    assert_response :forbidden

    finish lesson
    get study_class_lesson_path(lesson)
    assert_select ".study-question[data-step='3'] .quiz-option", 2
    assert_includes response.body, "first answers were right 1 of 1 times"
    assert_not_includes response.body, "EXPLAIN-TEXT"
    assert_select "a[href=?]", homework_class_lesson_path(lesson), text: "Start homework"
  end

  test "homework is handed in one task at a time and waits for the professor" do
    lesson(lesson_number: 1)
    lesson.update!(homework: lesson.homework * 2) # two tasks
    sign_in_as users(:one)
    finish lesson
    get portal_path
    assert_select ".today-homework a[href=?]", homework_class_lesson_path(lesson)

    get homework_class_lesson_path(lesson)
    assert_response :success
    assert_select ".classroom[data-classroom-homework-value=true][data-classroom-index-value='0']"
    assert_select "template[data-classroom-target=template]", 2
    assert_includes response.body, "Homework task 1"

    post homework_class_lesson_path(lesson), params: { task_index: 1, work: "skipping ahead" }, as: :json
    assert_response :unprocessable_entity
    post homework_class_lesson_path(lesson), params: { task_index: 0, work: "" }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, users(:one).homework_submissions.count

    post homework_class_lesson_path(lesson), params: { task_index: 0, work: "x = 5" }, as: :json
    assert_equal({ "handed_in" => 1, "complete" => false }, response.parsed_body.slice("handed_in", "complete"))
    post homework_class_lesson_path(lesson), params: { task_index: 0, work: "x = 2 + 3" }, as: :json # doing it again replaces the work
    post homework_class_lesson_path(lesson), params: { task_index: 1, work: "x = 5\nx" }, as: :json
    assert response.parsed_body["complete"]
    assert_equal [ "x = 2 + 3", "x = 5\nx" ], users(:one).homework_submissions.order(:task_index).pluck(:work)

    get study_class_lesson_path(lesson)
    assert_includes response.body, "Handed in · awaiting review"
    assert_select ".handed-in pre", text: "x = 2 + 3"
    assert_select ".handed-in button[data-copy*='Task 2: Set x.']"
    assert_includes response.body, "the portal doesn't grade homework"
    get portal_path
    assert_select ".today-homework", 0
    get class_lessons_path
    assert_includes response.body, "Homework handed in · awaiting review"
  end
end
