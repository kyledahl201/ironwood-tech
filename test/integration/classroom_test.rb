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

  test "a Python lesson parses, plays in the Python tools, and loads Python only from this site" do
    attrs = ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read)
    assert_equal "Made up: Python", attrs[:title]
    assert_equal [ nil, "pyrepl", "python" ], attrs[:steps].map { |s| s["mode"] }
    assert_equal "def made_up(n):\n    pass\n", attrs[:steps][2]["starter"] # indenting is kept
    python = ClassLesson.create!(attrs)

    sign_in_as users(:one)
    get class_lesson_path(python)
    assert_response :success
    assert_select "select[data-classroom-target=mode] option", 10
    assert_select "select[data-classroom-target=mode] option[value=pyrepl][selected]", text: "Python console"
    assert_select "select[data-classroom-target=mode] option[value=python]", text: "Python editor"
    assert_select ".tool[data-mode=pyrepl] input#pyrepl-input[aria-label='Type a line of Python and press Enter']"
    assert_select ".tool[data-mode=irb] input#irb-input"
    assert_select ".tool-editor[data-mode=editor]", 1 # one editor serves both languages
    runtimes = JSON.parse(css_select(".classroom").first["data-classroom-runtimes-value"])
    assert_equal({ "name" => "Python", "worker" => "/lab/python-worker.js", "runtime" => "/lab/pyodide/" }, runtimes["python"].except("megabytes"))
    assert runtimes["python"].key?("megabytes") # the size of the download, for the first-load message (nil when the files aren't fetched)
    assert_equal "/lab/ruby-worker.js", runtimes["ruby"]["worker"]
    assert_includes response.body, "press Enter on an empty line to run it"
    assert File.exist?(Rails.root.join("public/lab/python-worker.js")), "the Python worker is committed"
  end

  test "a check that can't work in a step's tool is refused" do
    attrs = ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read)
    attrs[:steps][2]["checks"] << { "type" => "cwd_is", "expected" => "~/x", "label" => "x" }
    record = ClassLesson.new(attrs)
    assert_not record.valid?
    assert_match(/step 3 uses checks that don't work in python: cwd_is/, record.errors.full_messages.to_sentence)
  end

  test "a JavaScript lesson parses and plays in the JavaScript tools, with nothing to download" do
    attrs = ClassLessonMarkdown.parse(file_fixture("js_lesson.md").read)
    assert_equal [ nil, "jsrepl", "js" ], attrs[:steps].map { |s| s["mode"] }
    assert_equal "function madeUp(n) {\n  // your code here\n}\n", attrs[:steps][2]["starter"]
    assert_equal "madeUp([1, 2]) returns [2, 4]", attrs[:steps][2]["checks"][0]["label"]
    lesson = ClassLesson.create!(attrs)

    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_response :success
    assert_select "select[data-classroom-target=mode] option[value=jsrepl][selected]", text: "JavaScript console"
    assert_select "select[data-classroom-target=mode] option[value=js]", text: "JavaScript editor"
    assert_select ".tool[data-mode=jsrepl] input#jsrepl-input[aria-label='Type a line of JavaScript and press Enter']"
    assert_select ".tool[data-mode=jsrepl] label.term-prompt", text: ">"
    runtimes = JSON.parse(css_select(".classroom").first["data-classroom-runtimes-value"])
    assert_equal({ "name" => "JavaScript", "worker" => "/lab/js-worker.js", "runtime" => "", "megabytes" => nil }, runtimes["javascript"])
    assert_includes response.body, "An open bracket keeps the entry going until you close it."
    assert File.exist?(Rails.root.join("public/lab/js-worker.js")), "the JavaScript worker is committed"
    assert_no_match(/https?:\/\//, File.read(Rails.root.join("public/lab/js-worker.js"))) # it loads nothing from anywhere

    bad = ClassLessonMarkdown.parse(file_fixture("js_lesson.md").read)
    bad[:steps][2]["checks"] << { "type" => "rows_are", "call" => "", "expected" => "[[1]]", "label" => "x" }
    record = ClassLesson.new(bad)
    assert_not record.valid?
    assert_match(/step 3 uses checks that don't work in js: rows_are/, record.errors.full_messages.to_sentence)
  end

  test "the JavaScript tour is seeded as a tour and never prints a finished answer" do
    lesson = ClassLesson.new(ClassLessonMarkdown.parse(Rails.root.join("db/seeds/lessons/demo-js.md").read))
    assert lesson.valid?, lesson.errors.full_messages.to_sentence
    assert lesson.tour?
    assert_equal %w[jsrepl js], lesson.steps.filter_map { |s| s["mode"] }.uniq
    tasks = lesson.steps.select { |s| s["kind"] == "try" }
    assert_equal 5, tasks.size
    assert tasks.all? { |s| s["hints"].any? }
    (tasks.flat_map { |s| s["hints"] } + tasks.filter_map { |s| s["starter"] }).each do |nudge|
      assert_no_match(/toUpperCase\(\)\s*\+|\.filter\(|return\s+n\s*\*\s*2|school\.length|let\s+school\s*=/, nudge)
    end
  end

  test "a web page lesson parses and plays in the web page editor with a sandboxed preview" do
    attrs = ClassLessonMarkdown.parse(file_fixture("web_lesson.md").read)
    assert_equal [ nil, "web" ], attrs[:steps].map { |s| s["mode"] }
    checks = attrs[:steps][1]["checks"]
    assert_equal [ "2", "", "", "Made up", "2em", "#F5F3EF", "(?i)<!doctype html>" ], checks.map { |c| c["expected"] }
    assert_equal [ "the menu has two links", "The page has footer", "there is a main part", "h2 says Made up", "h2 has font-size 2em", "the box is linen", "the page starts with a doctype" ], checks.map { |c| c["label"] }
    assert_equal "h2 { font-size }", checks[4]["call"]
    lesson = ClassLesson.create!(attrs)

    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_response :success
    assert_select "select[data-classroom-target=mode] option[value=web][selected]", text: "Web page (HTML and CSS)"
    # The preview can't run scripts, submit forms, open windows or leave its frame.
    assert_select "iframe.preview-frame[data-classroom-target=preview][sandbox='allow-same-origin'][title='Preview of your page'][hidden]"
    assert_includes response.body, "The preview shows your page as you type."
    assert_select ".tool-editor .page-notes[data-classroom-target=notes][role=status][hidden] ul"
    assert_select ".tool-editor button.flip-preview[data-action='classroom#flipPreview'][aria-pressed=false][hidden]", text: "Show preview"

    { "rows_are" => /step 2 uses checks that don't work in web: rows_are/, "method_returns" => /step 2 uses checks that don't work in web: method_returns/ }.each do |type, message|
      bad = ClassLessonMarkdown.parse(file_fixture("web_lesson.md").read)
      bad[:steps][1]["checks"] << { "type" => type, "call" => "x", "expected" => "[[1]]", "label" => "x" }
      record = ClassLesson.new(bad)
      assert_not record.valid?
      assert_match message, record.errors.full_messages.to_sentence
    end
    bad = ClassLessonMarkdown.parse(file_fixture("web_lesson.md").read)
    bad[:steps][1]["checks"][4]["call"] = "h2 font-size"
    assert_match(/step 2 has a style check that doesn't name an element and a property, like h1 \{ color \}/, ClassLesson.new(bad).tap(&:valid?).errors.full_messages.to_sentence)
    bad = ClassLessonMarkdown.parse(file_fixture("web_lesson.md").read)
    bad[:steps][1]["checks"][1]["call"] = ""
    assert_match(/step 2 has a page check with nothing to look for/, ClassLesson.new(bad).tap(&:valid?).errors.full_messages.to_sentence)
    # Page checks need a page, so a python step or an on-your-Mac step can't use them.
    sql = ClassLessonMarkdown.parse(file_fixture("js_lesson.md").read)
    sql[:steps][2]["checks"] << { "type" => "page_has", "call" => "h1", "expected" => "", "label" => "x" }
    assert_match(/step 3 uses checks that don't work in js: page_has/, ClassLesson.new(sql).tap(&:valid?).errors.full_messages.to_sentence)
  end

  test "the web page tour is seeded as a tour and never prints a finished answer" do
    lesson = ClassLesson.new(ClassLessonMarkdown.parse(Rails.root.join("db/seeds/lessons/demo-web.md").read))
    assert lesson.valid?, lesson.errors.full_messages.to_sentence
    assert lesson.tour?
    assert_equal %w[web], lesson.steps.filter_map { |s| s["mode"] }.uniq
    tasks = lesson.steps.select { |s| s["kind"] == "try" }
    assert_equal 4, tasks.size
    assert tasks.all? { |s| s["hints"].any? }
    (tasks.flat_map { |s| s["hints"] } + tasks.filter_map { |s| s["starter"] }).each do |nudge|
      assert_no_match(/<h1>|<li>|<ul>|<p\b|h1\s*\{|color\s*:|text-align\s*:|class="note"|\.note\s*\{/, nudge)
    end
  end

  test "a git lesson parses its repository checks and plays in the practice Terminal" do
    attrs = ClassLessonMarkdown.parse(file_fixture("git_lesson.md").read)
    checks = attrs[:steps][0]["checks"]
    assert_equal [ "~/made-up", "made-up", "spare", "3", "1", nil, "(?i)^add ", "spare", "docs/made-up.md" ], checks.map { |c| c["expected"] }
    assert_equal [ "~/made-up is a Git project", "You are on the branch made-up", "a spare branch is waiting", "This branch has at least 3 commits", "This branch has at least 1 commit", "Nothing is left to commit",
                   "the message starts with Add", "spare is merged into the branch you are on", "docs/made-up.md is in the last commit" ], checks.map { |c| c["label"] }
    lesson = ClassLesson.create!(attrs)
    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_response :success
    assert_select "select[data-classroom-target=mode] option[value=terminal][selected]"

    # Repository checks need the practice Terminal: not an editor, and not a real Mac.
    bad = ClassLessonMarkdown.parse(file_fixture("js_lesson.md").read)
    bad[:steps][2]["checks"] << { "type" => "git_clean", "label" => "x" }
    assert_match(/step 3 uses checks that don't work in js: git_clean/, ClassLesson.new(bad).tap(&:valid?).errors.full_messages.to_sentence)
    bad = ClassLessonMarkdown.parse(file_fixture("git_lesson.md").read)
    bad[:steps][0]["kind"] = "mac"
    assert_match(/step 1 is an on-your-Mac step, which can't use git_repo_is/, ClassLesson.new(bad).tap(&:valid?).errors.full_messages.to_sentence)
    bad = ClassLessonMarkdown.parse(file_fixture("git_lesson.md").read)
    bad[:steps][0]["checks"][3]["expected"] = "a few"
    assert_match(/step 1 has a git_commits check without a number of commits/, ClassLesson.new(bad).tap(&:valid?).errors.full_messages.to_sentence)
  end

  test "the git tour is seeded as a tour and its hints never hand over a whole command line" do
    lesson = ClassLesson.new(ClassLessonMarkdown.parse(Rails.root.join("db/seeds/lessons/demo-git.md").read))
    assert lesson.valid?, lesson.errors.full_messages.to_sentence
    assert lesson.tour?
    assert_equal %w[terminal], lesson.steps.filter_map { |s| s["mode"] }.uniq
    tasks = lesson.steps.select { |s| s["kind"] == "try" }
    assert_equal 6, tasks.size
    assert tasks.all? { |s| s["hints"].any? }
    tasks.flat_map { |s| s["hints"] }.each do |nudge|
      assert_no_match(/mkdir notes|cd notes|git add plan|git add \.|git commit -m "|git switch -c ideas|git switch main|git merge ideas/, nudge)
    end
  end

  test "a SQL lesson parses, plays in the SQL tools, and loads SQLite only from this site" do
    attrs = ClassLessonMarkdown.parse(file_fixture("sql_lesson.md").read)
    assert_equal [ nil, "sqlrepl", "sql" ], attrs[:steps].map { |s| s["mode"] }
    assert_equal "SELECT name\nFROM members\n", attrs[:steps][2]["starter"]
    console, editor = attrs[:steps][1]["checks"], attrs[:steps][2]["checks"]
    assert_equal [ "The only column is name", "The columns are name, town", "Your result has the right rows", "nobody was removed", "You typed the right command" ], console.map { |c| c["label"] }
    assert_equal '[["Made Up", "Nowhere"]]', console[2]["expected"]
    assert_equal [ "SELECT count(*) FROM members", "[[6]]" ], console[3].values_at("call", "expected")
    assert_equal "Your result has the right rows, in the right order", editor[0]["label"]
    assert_equal [ [ "Made Up" ], [ nil ], [ 3.5 ] ], JSON.parse(editor[0]["expected"])
    assert_equal "sql", attrs[:homework][0]["mode"]
    lesson = ClassLesson.create!(attrs)

    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_response :success
    assert_select "select[data-classroom-target=mode] option[value=sqlrepl][selected]", text: "SQL console"
    assert_select "select[data-classroom-target=mode] option[value=sql]", text: "SQL editor"
    assert_select ".tool[data-mode=sqlrepl] input#sqlrepl-input[aria-label='Type a line of SQL and press Enter']"
    assert_select ".tool[data-mode=sqlrepl] label.term-prompt", text: "sql>"
    assert_select ".tool-editor[data-mode=editor]", 1 # one editor serves every language
    runtimes = JSON.parse(css_select(".classroom").first["data-classroom-runtimes-value"])
    assert_equal({ "name" => "SQL", "worker" => "/lab/sql-worker.js", "runtime" => "/lab/sqlite/" }, runtimes["sql"].except("megabytes"))
    assert_includes response.body, "end it with a semicolon"
    assert_includes response.body, "Write it in the SQL editor below, then press Check."
    assert_no_match(/\[\[&quot;Made Up|Made Up&quot;, &quot;Nowhere/, css_select(".chips").map(&:to_s).join) # the rows a check expects are not printed on the page's chips
    assert File.exist?(Rails.root.join("public/lab/sql-worker.js")), "the SQL worker is committed"
    assert_no_match(/cdn|jsdelivr|unpkg|sql\.js\.org/i, File.read(Rails.root.join("vendor/lab-src/sql-worker.js")).gsub(/^\/\/.*$/, ""))
  end

  test "SQL checks only go where they can work, and their rows must be readable" do
    parsed = -> { ClassLessonMarkdown.parse(file_fixture("sql_lesson.md").read) }
    errors = ->(attrs) { ClassLesson.new(attrs).tap(&:valid?).errors.full_messages.to_sentence }
    assert ClassLesson.new(parsed.call).valid?

    attrs = parsed.call
    attrs[:steps][2]["checks"] << { "type" => "method_returns", "call" => "x", "expected" => "1", "label" => "x" }
    assert_match(/step 3 uses checks that don't work in sql: method_returns/, errors.call(attrs))

    attrs = parsed.call
    attrs[:steps][1]["checks"] << { "type" => "value_is", "call" => "x", "expected" => "1", "label" => "x" }
    assert_match(/step 2 uses checks that don't work in sqlrepl: value_is/, errors.call(attrs))

    attrs = parsed.call
    attrs[:steps][1]["mode"] = "irb"
    assert_match(/step 2 uses checks that don't work in irb: columns_are, columns_are, rows_any_order, rows_are/, errors.call(attrs))

    [ "[[1], ", "7", '{"a": 1}', "[1, 2]", "[[[1]]]", "" ].each do |bad|
      attrs = parsed.call
      attrs[:steps][2]["checks"][0]["expected"] = bad
      assert_match(/step 3 has rows that aren't a JSON list of rows/, errors.call(attrs), bad.inspect)
    end

    attrs = parsed.call
    attrs[:homework][0]["checks"][0]["expected"] = "oops"
    assert_match(/step 4 has rows that aren't a JSON list of rows/, errors.call(attrs)) # homework is checked too

    mac = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    step = mac[:steps].find { |s| s["kind"] == "mac" }
    if step
      step["checks"] << { "type" => "rows_are", "call" => "", "expected" => "[[1]]", "label" => "x" }
      assert_match(/is an on-your-Mac step, which can't use rows_are/, errors.call(mac))
    end
  end

  test "the SQL tour is seeded as a tour and never prints a finished query" do
    text = Rails.root.join("db/seeds/lessons/demo-sql.md").read
    lesson = ClassLesson.new(ClassLessonMarkdown.parse(text))
    assert lesson.valid?, lesson.errors.full_messages.to_sentence
    assert lesson.tour?
    assert_equal %w[sqlrepl sql], lesson.steps.filter_map { |s| s["mode"] }.uniq
    tasks = lesson.steps.select { |s| s["kind"] == "try" }
    assert_equal 6, tasks.size
    assert tasks.all? { |s| s["hints"].any? }
    # Hints and starters nudge; none holds a whole statement that would pass.
    (tasks.flat_map { |s| s["hints"] } + tasks.filter_map { |s| s["starter"] }).each do |nudge|
      assert_no_match(/select\b[^`]*\bfrom\b[^`]*\bwhere\b|update\s+members\s+set/i, nudge.gsub(/^--.*$/, ""))
    end
  end

  test "tours are always open, and Today only points at courses the student is taking" do
    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    in_progress = users(:one).course_records.select(&:in_progress?).map(&:code)
    assert in_progress.any?
    assert_not_includes in_progress, "AI 360"
    ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read))
    tour = ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("lesson.md").read).merge(slug: "zz-tour", course_code: "TOUR", lesson_number: 2))
    assert tour.unlocked_for?(users(:one))
    assert_nil ClassLesson.next_for(users(:one)) # the only open lesson is in a course not in progress
    sign_in_as users(:one)
    get class_lessons_path
    assert_select "a[href=?]", class_lesson_path("zz-py") # still there to open by choice

    assert_equal "zz-py", ClassLesson.next_for(users(:two)).slug # no transcript yet: any open lesson is offered
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
    assert_redirected_to course_path("cs-101") # lesson 1 hasn't happened yet: back to the course, which says when it opens
    follow_redirect!
    assert_select ".flash, [role=alert], [role=status]", text: /opens when CS 101 lesson 1 is finished/

    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    users(:one).course_records.find_by(code: "CS 101").update!(lessons_done: 1)
    get portal_path
    assert_select "a.btn[href=?]", class_lesson_path(lesson), text: "Start class"
    get class_lessons_path
    assert_redirected_to class_lesson_path(lesson) # the Classroom tab opens the class this student is in
    get course_path("cs-101")
    assert_select ".ex-list a[href=?]", class_lesson_path(lesson)

    get class_lesson_path(lesson)
    assert_response :success
    assert_select ".classroom[data-controller~=classroom]"
    assert_select "template[data-classroom-target=template]", 6
    assert_select "select[data-classroom-target=mode] option", 10
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
    first_time = users(:one).homework_submissions.first.submitted_at
    post homework_class_lesson_path(lesson), params: { task_index: 0, work: "x = 999 # changed after handing in" }, as: :json
    assert_response :unprocessable_entity # handed-in work is locked
    assert_equal "That task is already handed in.", response.parsed_body["error"]
    post homework_class_lesson_path(lesson), params: { task_index: 1, work: "x = 5\nx" }, as: :json
    assert response.parsed_body["complete"]
    post homework_class_lesson_path(lesson), params: { task_index: 1, work: "overwrite" }, as: :json
    assert_response :unprocessable_entity
    assert_equal [ "x = 5", "x = 5\nx" ], users(:one).homework_submissions.order(:task_index).pluck(:work)
    assert_equal first_time, users(:one).homework_submissions.order(:task_index).first.submitted_at

    get study_class_lesson_path(lesson)
    assert_includes response.body, "Handed in · awaiting review"
    assert_select ".handed-in pre", text: "x = 5"
    assert_select ".handed-in .handed-in-task", text: "Set x.", count: 2
    assert_select ".handed-in button[data-copy*='Task 2: Set x.']"
    assert_includes response.body, "the portal doesn't grade homework"
    get portal_path
    assert_select ".today-homework", 0
    get course_path("cs-101")
    assert_includes response.body, "Homework handed in · awaiting review"
  end

  test "flashcards and question retries are recorded, apart from the class score" do
    lesson(lesson_number: 1)
    lesson.update!(flashcards: [ { "front" => "A", "back" => "1" }, { "front" => "B", "back" => "2" } ])
    sign_in_as users(:one)
    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 1, retry: true }, as: :json
    assert_response :forbidden # no retries before class is finished
    finish lesson # answers the class question right the first time

    post study_card_class_lesson_path(lesson), params: { card: 0, result: "again" }, as: :json
    post study_card_class_lesson_path(lesson), params: { card: 0, result: "known" }, as: :json
    post study_card_class_lesson_path(lesson), params: { card: 0, result: "known" }, as: :json # counted once
    post study_card_class_lesson_path(lesson), params: { card: 7, result: "known" }, as: :json # no such card
    assert_equal({ "known" => [ 0 ], "done" => false, "decks_finished" => 0 }, response.parsed_body.slice("known", "done", "decks_finished"))
    record = lesson.study_records.find_by!(user: users(:one))
    assert_equal [ 1, 1, "Flashcards 1 of 2 known" ], [ record.cards_known, record.cards_again, record.summary ]

    get study_class_lesson_path(lesson) # a reload brings the deck back where it was
    assert_select "[data-study-known-value='[0]']"

    post study_card_class_lesson_path(lesson), params: { card: 1, result: "known" }, as: :json
    assert response.parsed_body["done"]
    assert_equal 1, record.reload.decks_finished
    assert_not_nil record.deck_finished_at
    post study_restart_class_lesson_path(lesson), params: { what: "deck" }, as: :json
    assert_equal [ [], 1 ], [ record.reload.known_cards, record.decks_finished ]

    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 0, retry: true }, as: :json # wrong on retry
    post quiz_class_lesson_path(lesson), params: { step: 3, choice: 1, retry: true }, as: :json # only the first counts
    assert_equal "0 of 1 right on the first try this round", response.parsed_body["summary"]
    assert_equal [ 0, 1 ], [ record.reload.retry_right, record.retry_total ]
    progress = lesson.progress_for(users(:one))
    assert_equal [ 1, 1 ], [ progress.quiz_right, progress.quiz_total ] # the class score is untouched

    get study_class_lesson_path(lesson)
    assert_includes response.body, "Deck finished 1 time"
    assert_includes response.body, "Retry: 0 of 1 right on the first try this round."
    assert_includes response.body, "first answers were right 1 of 1 times"
    get course_path("cs-101")
    assert_includes response.body, "Deck finished 1 time · Questions 0 of 1 right on retry"

    post study_restart_class_lesson_path(lesson), params: { what: "questions" }
    assert_redirected_to study_class_lesson_path(lesson, anchor: "questions")
    assert_equal 0, record.reload.retry_total
  end

  def pulse(seconds, activity: "class", course: "CS 101")
    post portal_pulse_path, params: { seconds: seconds, course_code: course, activity: activity }, as: :json
    response.parsed_body
  end

  test "time is logged by itself, and never faster than the clock" do
    user = users(:one)
    sign_in_as user
    auto = -> { user.study_sessions.auto.order(:activity).pluck(:activity, :seconds, :minutes) }
    start = Time.current.change(hour: 12, usec: 0) # midday, so the test never crosses midnight

    travel_to(start) do
      assert_equal({ "today_minutes" => 0, "today_label" => "Your time here is logged by itself" }, pulse(0).slice("today_minutes", "today_label"))
      assert_equal 0, StudySession.count # a report of no time records nothing
      pulse(-30)
      assert_equal 0, StudySession.count

      assert_equal 0, pulse(5)["today_minutes"] # a 5-second visit logs 0 minutes
      assert_equal [ [ "class", 5, 0 ] ], auto.call
      assert_equal 0, ProgressStats.new(user).minutes_by_day.values.sum
      get portal_study_sessions_path
      assert_select ".log-list li", 0 # and it does not show up as a session
      assert_select ".log-total strong", "0"

      pulse(60) # sent again in the same second: nothing is added
      assert_equal [ [ "class", 5, 0 ] ], auto.call
    end

    travel_to(start + 30.seconds) { pulse(30) }
    assert_equal [ [ "class", 35, 0 ] ], auto.call
    travel_to(start + 60.seconds) { assert_equal "1 min logged today", pulse(30)["today_label"] }
    assert_equal [ [ "class", 65, 1 ] ], auto.call

    travel_to(start + 10.minutes) do
      pulse(5000) # one report adds 90 seconds at most
      assert_equal [ [ "class", 155, 2 ] ], auto.call
    end

    # Two windows open side by side: homework and a study page report the same half minute.
    travel_to(start + 10.minutes + 30.seconds) do
      pulse(30, activity: "homework")
      pulse(30, activity: "study")
      pulse(30, activity: "made-up") # an unknown activity counts as study, and is capped the same way
    end
    assert_equal [ [ "class", 155, 2 ], [ "homework", 30, 1 ] ], auto.call # 185 seconds is 3 minutes, once
    travel_to(start + 10.minutes + 50.seconds) do
      pulse(30, activity: "study") # only the 20 seconds that passed
      assert_equal [ [ "class", 155, 2 ], [ "homework", 30, 1 ], [ "study", 20, 0 ] ], auto.call
      assert_equal 205, user.study_sessions.auto.sum(:seconds)
      assert_equal 3, ProgressStats.new(user).minutes_by_day.values.sum # 205 seconds: 3 minutes on the heatmap, not 5
      assert_operator user.study_sessions.auto.sum(:seconds), :<=, 10.minutes + 50.seconds
    end

    sign_out
    assert_no_difference -> { StudySession.sum(:seconds) } do
      post portal_pulse_path, params: { seconds: 30 }, as: :json
    end
  end

  test "pages that count time say so, and the lab no longer asks you to log it" do
    lesson(lesson_number: 1)
    sign_in_as users(:one)
    get class_lesson_path(lesson)
    assert_select ".classroom[data-controller~=pulse][data-pulse-activity-value=class][data-pulse-course-value='CS 101']"
    assert_includes response.body, "Your time here is logged by itself"
    get study_class_lesson_path(lesson)
    assert_select "[data-controller~=pulse][data-pulse-activity-value=study] [data-pulse-target=today]"
    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    get exercise_path(exercises(:first))
    assert_select ".lab[data-controller~=pulse][data-pulse-activity-value=lab]"
    assert_select "[data-action='lab#logTime']", 0
  end

  test "offline time is added with one tap, and the log shows what was automatic" do
    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    sign_in_as users(:one)
    pulse(60)

    get portal_study_sessions_path
    assert_select "form.quick-add select", 0 # no dropdowns
    assert_select "form.quick-add input[type=text], form.quick-add input[type=date], form.quick-add input[type=number]", 0 # nothing to type
    assert_select "form.quick-add button[name='study_session[minutes]']", 6
    assert_select "form.quick-add input[name='study_session[course_code]'][value='CS 101'][checked]" # the course in progress is preselected
    assert_select ".log-breakdown li", text: /Class.*logged by itself.*1 min/m

    post portal_study_sessions_path, params: { study_session: { minutes: 45, activity: "reading", course_code: "CS 101" }, when: "yesterday" }
    assert_redirected_to portal_study_sessions_path
    follow_redirect!
    assert_includes response.body, "Added 45 minutes: Reading, for yesterday."
    added = users(:one).study_sessions.manual.sole
    assert_equal [ 45, "reading", "CS 101", Time.zone.yesterday, "manual" ], [ added.minutes, added.activity, added.course_code, added.studied_on, added.source ]
    assert_select ".log-list li", text: /Reading.*Added by you.*45 min/m
    assert_select ".log-list li", text: /Class.*Logged by itself.*1 min/m

    get portal_path
    assert_select ".quick-log form.quick-add button[name='study_session[minutes]']", 6
  end

  test "a course's tutor kit downloads as a zip of the faculty's files, and holds no answers" do
    kit = TutorKit.for("AI 360")
    assert_equal "README.md", kit.names.first
    assert_includes kit.names, "PROJECT-INSTRUCTIONS.md"
    assert_nil TutorKit.for("CS 101")
    assert_nil TutorKit.for("../..")

    # No file in the kit defines a function a lesson asks the student to write.
    lessons = Dir[Rails.root.join("db/seeds/lessons/ai360-*.md")].map { |path| ClassLessonMarkdown.parse(File.read(path)) }
    asked = lessons.flat_map { |l| l[:steps] + l[:homework] }.flat_map { |s| Array(s["checks"]) }
                   .filter_map { |c| c["call"].to_s[/\A([a-z_]\w*)\(/, 1] if c["type"] == "method_returns" }.uniq - %w[sum len max min round]
    assert_operator asked.size, :>, 10
    kit.files.each do |path|
      text = File.read(path)
      asked.each { |name| assert_no_match(/def #{name}\b/, text, "#{File.basename(path)} defines #{name}") }
    end

    get tutor_kit_path("ai-360")
    assert_redirected_to new_session_path # signed-in students only
    ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read))
    sign_in_as users(:one)
    get tutor_kit_path("ai-360")
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_match(/ironwood-ai-360-tutor-kit\.zip/, response.headers["Content-Disposition"])

    # Read the first file back out of the zip by hand.
    zip = response.body.b
    signature, _version, _flags, method, _time, _date, crc, packed, size, name_length, _extra = zip.unpack("VvvvvvVVVvv")
    assert_equal [ 0x04034b50, 8 ], [ signature, method ]
    assert_equal "ironwood-ai-360-tutor-kit/README.md", zip[30, name_length]
    readme = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(zip[30 + name_length, packed])
    assert_equal File.binread(kit.files.first), readme
    assert_equal [ readme.bytesize, Zlib.crc32(readme) ], [ size, crc ]
    assert_equal kit.files.size, zip.scan([ 0x02014b50 ].pack("V")).size # one directory entry per file

    get tutor_kit_file_path("ai-360", "WEEK-01.md")
    assert_response :success
    assert_equal File.read(Rails.root.join("db/tutor_kits/ai-360/WEEK-01.md")), response.body
    get "/classroom/kits/ai-360/nope.md"
    assert_response :not_found
    get tutor_kit_path("cs-101")
    assert_response :not_found
  end

  test "the Week 1 lessons and the tutor kit state the same Python floor, and the check enforces it" do
    floor = "Python 3.11 or newer"
    lessons = %w[ai360-w1 ai360-w1-lab].to_h { |slug| [ slug, Rails.root.join("db/seeds/lessons/#{slug}.md").read ] }
    kit = TutorKit.for("AI 360").read("WEEK-01.md")

    lessons.each { |slug, text| assert_includes text, floor, "#{slug} doesn't state the floor" }
    assert_includes kit, floor, "the tutor's Week 1 notes don't state the floor"
    (lessons.values + [ kit ]).each do |text|
      assert_no_match(/Python 3\.(?:\d|10) or newer|3\.(?:\d|10)\+/, text, "an older floor is still stated somewhere")
    end

    lessons.each do |slug, text|
      lesson = ClassLessonMarkdown.parse(text)
      patterns = lesson[:steps].select { |s| s["kind"] == "mac" }.flat_map { |s| s["checks"] }
                               .filter_map { |c| c["expected"] if c["expected"].to_s.start_with?("^Python 3\\.(") }
      assert_equal 1, patterns.size, "#{slug} should check the Python version against the floor exactly once"
      check = Regexp.new(patterns.first)
      [ "Python 3.11.0", "Python 3.12.4", "Python 3.14.1" ].each { |v| assert_match check, v }
      [ "Python 3.9.6", "Python 3.10.14", "Python 3.1.5", "Python 2.7.18" ].each { |v| assert_no_match check, v }
    end
  end

  test "the .env step writes the example file by hand and refuses one copied from .env" do
    lesson = ClassLessonMarkdown.parse(Rails.root.join("db/seeds/lessons/ai360-w1-lab.md").read)
    step = lesson[:steps].find { |s| s["kind"] == "mac" && s["run"].to_a.any? { |c| c.include?(".env.example") } }

    assert step, "the lab should have a .env step"
    assert step["run"].none? { |c| c.match?(/cp\s+\.env\s/) }, "the step must not copy .env into the example"
    assert_includes step["run"], "cat .env.example"

    checks = step["checks"].map { |c| Regexp.new(c["expected"]) }
    placeholders = "HOME_LAT=0.0\nHOME_LON=0.0\nPLACE_NAME=Your town\n"
    copied = "HOME_LAT=41.88\nHOME_LON=-87.63\nPLACE_NAME=Chicago\n"
    rest = "Forecast for Chicago\nChanges to be committed:\n\tnew file:   week-01-weather-brief/.env.example\n\nIgnored files:\n\tweek-01-weather-brief/.env\n"
    assert checks.all? { |c| c.match?(placeholders + rest) }
    assert_not checks.all? { |c| c.match?(copied + rest) }, "a copied example file must not pass"
  end

  test "a course page offers the kit for its course only, and the workbench has Copy for my tutor" do
    lesson(lesson_number: 1)
    python = ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read))
    sign_in_as users(:one)
    get course_path("cs-101")
    assert_select "details.kit", 0
    get course_path("ai-360")
    assert_select "details.kit", 1
    assert_select "details.kit a[href=?]", tutor_kit_path("ai-360"), text: "Download the tutor kit"
    assert_select "details.kit a[href=?]", tutor_kit_file_path("ai-360", "WEEK-02.md")
    assert_select "details.kit", text: /It holds no answers.*can't see the portal/m

    get class_lesson_path(python)
    assert_select ".bench-bar button[data-action='classroom#copyForTutor'][aria-label='Copy for my tutor'] .when-wide", text: "Copy for my tutor"
    assert_select ".bench-bar button[data-action='classroom#copyForTutor'] .when-narrow[aria-hidden=true]", text: "Copy" # the short label a phone shows
    assert_select ".classroom[data-classroom-about-value='AI 360 · Lesson 1 · Made up: Python · Prof. Example']"
  end
end
