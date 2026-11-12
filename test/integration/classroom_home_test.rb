require "test_helper"

# The Classroom tab, the one course list, and the professor's chat in class.
class ClassroomHomeTest < ActionDispatch::IntegrationTest
  def script = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)

  def lessons_for_everyone
    @tour = ClassLesson.create!(script.merge(slug: "zz-tour", course_code: "TOUR", lesson_number: 1, title: "Made up: the tour"))
    @one = ClassLesson.create!(script.merge(slug: "zz-l1", lesson_number: 1, title: "Made up: one"))
    @two = ClassLesson.create!(script.merge(slug: "zz-l2", lesson_number: 2, title: "Made up: two"))
  end

  def finish(lesson)
    lesson.steps.each_index do |i|
      post quiz_class_lesson_path(lesson), params: { step: i, choice: 1 }, as: :json if lesson.steps[i]["kind"] == "quiz"
      post progress_class_lesson_path(lesson), params: { step_index: i + 1 }, as: :json
    end
  end

  def with_tutor_key
    before = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "made-up-key"
    yield
  ensure
    ENV["ANTHROPIC_API_KEY"] = before
  end

  test "a student who hasn't begun gets a welcome, one class to start and the full course list" do
    lessons_for_everyone
    sign_in_as users(:two)
    assert_nil ClassLesson.current_for(users(:two))
    get class_lessons_path
    assert_response :success
    assert_select "h1", text: "Welcome to the classroom, Riley"
    assert_select ".welcome-first .eyebrow", text: "A good first class"
    assert_select ".welcome-first h2", text: "Made up: the tour"
    assert_select ".welcome-first a.btn[href=?]", class_lesson_path(@tour), text: "Start this class"
    # The button is a real link to the Courses page, which the page's script turns into the list drawn over the page.
    assert_select ".welcome-first a[href=?][data-action='course-dialog#open'][aria-haspopup=dialog]", courses_path, text: "Show full course list"
    assert_select "dialog.course-dialog[aria-labelledby=course-dialog-title] h2#course-dialog-title", text: "All courses"
    assert_select "dialog .course-pick", 4 # the tour, CS 101 and the two reading courses
    assert_select "dialog .course-pick h3", text: "Start here: a tour of the classroom"
    assert_select "dialog .course-pick a.btn[href=?]", class_lesson_path(@one), text: /Start\s*Intro to Programming in Ruby/
    assert_select "dialog .course-pick .course-state", text: "Not started · 2 classes"
    assert_select "section .welcome > .course-list", 0 # a new student isn't handed the whole list before they ask
    assert_includes response.body, "AI tutor personas, not people"
  end

  test "the Classroom tab opens the class the student is in, and moves on when they finish it" do
    lessons_for_everyone
    sign_in_as users(:two)
    get class_lesson_path(@one) # looking isn't starting
    get class_lessons_path
    assert_response :success

    post progress_class_lesson_path(@one), params: { step_index: 1 }, as: :json
    get class_lessons_path
    assert_redirected_to class_lesson_path(@one)

    # The newest class they worked in wins.
    travel 1.minute do
      post progress_class_lesson_path(@tour), params: { step_index: 1 }, as: :json
      assert_equal @tour, ClassLesson.current_for(users(:two))
      finish_from = ClassProgress.find_by(user: users(:two), class_lesson: @tour)
      finish_from.update!(step_index: @tour.steps.size, completed_at: Time.current)
    end
    assert_equal @one, ClassLesson.current_for(users(:two)) # the tour is done; lesson one is still open on the desk

    travel 2.minutes do
      (1...@one.steps.size).each do |i|
        post quiz_class_lesson_path(@one), params: { step: i, choice: 1 }, as: :json if @one.steps[i]["kind"] == "quiz"
        post progress_class_lesson_path(@one), params: { step_index: i + 1 }, as: :json
      end
      assert @one.completed_by?(users(:two))
      get class_lessons_path
      assert_redirected_to class_lesson_path(@two) # the next class of the course they just finished a class in
    end

    travel 3.minutes do
      finish @two
      assert_nil ClassLesson.current_for(users(:two))
      get class_lessons_path
      assert_response :success
      assert_select "h1", text: "You're caught up, Riley"
      assert_select ".welcome-first", 0 # nothing left to recommend
      assert_select ".welcome > .course-list .course-pick.is-finished .course-state", text: "Finished · 2 of 2 classes"
      assert_select ".welcome > .course-list .course-pick.is-finished a.btn[href=?]", class_lesson_path(@one), text: /Open again/
    end
  end

  test "pick shows the course list even with a class open, and marks the class the student is in" do
    lessons_for_everyone
    sign_in_as users(:two)
    post progress_class_lesson_path(@one), params: { step_index: 1 }, as: :json
    get class_lessons_path(pick: 1)
    assert_response :success
    assert_select "h1", text: "Pick a class"
    assert_select ".welcome-first .eyebrow", text: "Your class"
    assert_select ".welcome-first a.btn[href=?]", class_lesson_path(@one), text: "Resume class"
    assert_select ".welcome > .course-list .course-pick.is-current", 1
    assert_select ".welcome > .course-list .course-pick.is-current .meta", text: /In progress · 0 of 2 classes finished\s*·\s*You are in this class now/
    assert_select ".welcome > .course-list .course-pick.is-current a.btn[href=?]", class_lesson_path(@one), text: /Resume/
  end

  test "a transcript in progress sends a student who hasn't opened the classroom to their next class" do
    lessons_for_everyone
    TranscriptImport.call(file_fixture("transcript.md").read, user: users(:one))
    users(:one).course_records.find_by(code: "CS 101").update!(lessons_done: 1) # lesson 1 was taught in chat
    sign_in_as users(:one)
    get class_lessons_path
    assert_redirected_to class_lesson_path(@two)
  end

  test "Courses is one list: details in place, and one button into each course" do
    lessons_for_everyone
    bootcamp = Course.create!(title: "Agentic AI Bootcamp", slug: "agentic-ai-bootcamp", tagline: "Made-up tagline", level: "Intermediate", hours: "14 weeks", tutor_name: "Prof. Tomas Reyes", published: true, position: 3, outcomes: "Build an agent\nTest it")
    bootcamp.lessons.create!(position: 1, title: "Week 1 notes", body: "Read this.")
    py = ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("python_lesson.md").read))
    users(:two).enrollments.destroy_all
    sign_in_as users(:two)
    get courses_path
    assert_response :success
    assert_select ".course-list .course-pick", 5
    assert_select ".course-list .course-pick h3 a", text: "Start here: a tour of the classroom"
    assert_select ".course-pick .eyebrow", text: "CS 101 · Prof. Hale (AI tutor)"

    # The classroom course and its reading are one row, and the button goes to the classroom.
    assert_select ".course-pick h3 a[href=?]", course_path("agentic-ai-bootcamp"), text: "Agentic AI Bootcamp", count: 1
    assert_select ".course-pick a.btn[href=?]", class_lesson_path(py), text: /Start\s*Agentic AI Bootcamp/
    assert_select "#course-agentic-ai-bootcamp-more[hidden] dd", text: /1 class in the classroom, one step at a time and 1 reading lesson with an AI tutor/i
    assert_select "#course-agentic-ai-bootcamp-more li", text: "Build an agent"

    # Details is a link to the course page that the page's script opens in place.
    assert_select ".course-pick a.course-more-toggle[role=button][aria-expanded=false][aria-controls=course-cs-101-more][href=?]", course_path("cs-101"), text: /Details\s*of Intro to Programming in Ruby/
    assert_select "#course-cs-101-more[hidden] li", text: "Write methods, and tell puts from return"

    # A reading-only course starts with its own button.
    assert_select ".course-pick form[action=?] button", course_enrollment_path(courses(:free)), text: /Start\s*Free Course/
    post course_enrollment_path(courses(:free))
    get courses_path
    assert_select ".course-pick a.btn[href=?]", learn_lesson_path(courses(:free), 1), text: /Resume\s*Free Course/
    assert_select "form[action=?]", course_enrollment_path(courses(:free)), 0
  end

  test "a course page lists its classes and has one way in" do
    lessons_for_everyone
    sign_in_as users(:two)
    get course_path("cs-101")
    assert_response :success
    assert_select "h1", text: "Intro to Programming in Ruby"
    assert_select ".facts dd", text: "Prof. Hale, an AI tutor"
    assert_select ".ex-list .ex-row", 2
    assert_select ".ex-row.is-open a.ex-title[href=?]", class_lesson_path(@one)
    assert_select ".ex-row.is-locked .ex-tag", text: "Opens after lesson 1"
    assert_select ".buy-box a.btn[href=?]", class_lesson_path(@one), text: /Start/
    assert_select ".buy-box", text: /Lesson 1: Made up: one\. It opens in the classroom\./
    assert_includes response.body, "not an accredited school"

    get course_path("start-here")
    assert_select "h2", text: "The tours"
    get course_path(courses(:free))
    assert_response :success
    assert_select ".ex-list", 0
    get course_path("no-such-course")
    assert_response :not_found
  end

  test "the class bar switches class and opens the professor's chat, which says so when it isn't connected" do
    lessons_for_everyone
    sign_in_as users(:two)
    get class_lesson_path(@one)
    assert_response :success
    assert_select ".class-bar .crumbs a[href=?]", class_lessons_path(pick: 1), text: "Classroom"
    assert_select ".class-bar .crumbs a[href=?]", course_path("cs-101"), text: "CS 101"
    assert_select ".class-tools a[href=?][data-action='course-dialog#open']", class_lessons_path(pick: 1), text: "Switch class"
    assert_select "dialog.course-dialog h2", text: "Switch class"
    assert_select "dialog .course-pick.is-current h3", text: "Intro to Programming in Ruby"
    assert_select ".class-tools button[data-action='classroom#toggleTutor'][aria-expanded=false][aria-controls=class-tutor]", text: "Ask Prof. Example"
    assert_select "aside#class-tutor[hidden] .tutor-head", text: /AI tutor, not a person/
    assert_select "aside#class-tutor form", 0
    assert_select "aside#class-tutor .tutor-off", text: /live tutor isn't switched on yet.*Copy for my tutor/m

    with_tutor_key do
      get class_lesson_path(@one)
      assert_select "aside#class-tutor .tutor-off", 0
      assert_select "aside#class-tutor form[action=?][data-action*='classroom#attachWork']", class_lesson_tutor_messages_path(@one)
      assert_select "aside#class-tutor textarea[name='tutor_message[content]']"
      assert_select "aside#class-tutor input[type=hidden][name='tutor_message[context]'][data-classroom-target=tutorContext]"
      assert_select "aside#class-tutor input[type=checkbox][checked][data-classroom-target=tutorSendWork]"
      assert_select "aside#class-tutor .quick button", 3
    end
  end

  test "a question in class is saved with the student's workbench and answered in the background" do
    lessons_for_everyone
    sign_in_as users(:two)
    assert_difference -> { TutorMessage.count }, 2 do
      assert_enqueued_with(job: TutorReplyJob) do
        post class_lesson_tutor_messages_path(@one), params: { tutor_message: { content: "Why didn't that pass?", context: "Step 2 of 6\n\nWhat I typed: mkdri made-up" } }, as: :turbo_stream
      end
    end
    assert_response :success
    assert_select "turbo-stream[action=append][target=tutor-log] template .msg", 2
    assert_select "turbo-stream .msg-assistant .msg-who", text: "Prof. Example"
    assert_not_includes response.body, "mkdri" # the snapshot is for the tutor; the chat shows the question as asked
    question, placeholder = TutorMessage.order(:id).last(2)
    assert_equal [ @one, nil, "user", "Step 2 of 6\n\nWhat I typed: mkdri made-up" ], [ question.class_lesson, question.lesson, question.role, question.context ]
    assert placeholder.pending?
    perform_enqueued_jobs
    assert_equal Tutor::OFFLINE, placeholder.reload.content # no key in the test: nothing is sent anywhere

    get class_lesson_path(@one)
    assert_select "aside#class-tutor .msg-user", text: /Why didn't that pass\?/
    # Another student's page never shows it.
    sign_in_as users(:one)
    get class_lesson_path(@one)
    assert_select "aside#class-tutor .msg-user", 0
  end

  test "the chat refuses an empty question, a locked class and anything past the daily cap" do
    lessons_for_everyone
    sign_in_as users(:two)
    assert_no_difference -> { TutorMessage.count } do
      post class_lesson_tutor_messages_path(@one), params: { tutor_message: { content: "  " } }, as: :turbo_stream
      assert_response :unprocessable_entity
      assert_select "turbo-stream[action=update][target=tutor-alert]", text: /Type a question first/
      post class_lesson_tutor_messages_path(@two), params: { tutor_message: { content: "Tell me about lesson two" } }, as: :turbo_stream
      assert_response :forbidden
    end

    Tutor.daily_cap.times { users(:two).tutor_messages.create!(class_lesson: @one, role: "user", content: "q") }
    assert Tutor.over_cap?(users(:two), "CS 101")
    assert_not Tutor.over_cap?(users(:two), "TOUR") # the cap is per course
    assert_not Tutor.over_cap?(users(:two), courses(:free))
    assert_no_difference -> { TutorMessage.count } do
      assert_no_enqueued_jobs do
        post class_lesson_tutor_messages_path(@two.tap { ClassProgress.create!(user: users(:two), class_lesson: @one, step_index: @one.steps.size, completed_at: Time.current) }), params: { tutor_message: { content: "one more" } }, as: :turbo_stream
      end
    end
    assert_select "turbo-stream[target=tutor-alert]", text: /today's \d+ tutor questions for this course/
  end

  test "the classroom tutor is told the lesson so far and the student's newest work, and nothing it could leak" do
    lessons_for_everyone
    user = users(:two)
    ClassProgress.create!(user: user, class_lesson: @one, step_index: 1)
    user.tutor_messages.create!(class_lesson: @one, role: "user", content: "First question", context: "OLD SNAPSHOT")
    user.tutor_messages.create!(class_lesson: @one, role: "assistant", content: "First answer")
    user.tutor_messages.create!(class_lesson: @one, role: "user", content: "Second question", context: "NEW SNAPSHOT")
    user.tutor_messages.create!(class_lesson: @one, role: "assistant", content: "Thinking…", pending: true)
    user.tutor_messages.create!(class_lesson: @two, role: "user", content: "Another lesson's question")
    tutor = Tutor.for(TutorMessage.find_by(pending: true))

    prompt = tutor.send(:system_prompt)
    assert_includes prompt, "You are Prof. Example, an AI tutor persona"
    assert_includes prompt, "\"Made up: one\" (CS 101, lesson 1)"
    assert_includes prompt, "The student is Riley"
    assert_includes prompt, "the student is on step 2 of 6"
    assert_includes prompt, "Step 1 (teach):"
    assert_includes prompt, "Step 2 (try):"
    assert_includes prompt, "Checks: The folder ~/made-up exists; you made a folder"
    assert_includes prompt, "The lesson's own hints, in order: First hint. | Second hint."
    assert_not_includes prompt, "Step 3" # later steps are held back
    assert_not_includes prompt, "SECRET-RIGHT" # so a quiz answer can't be given away
    assert_includes prompt, "Never write the answer to a task that has checks"
    assert_includes prompt, "not a human"
    assert_includes prompt, "not an accredited school"
    assert_match(/never an\s+employer's data/, prompt)

    assert_equal [ { role: :user, content: "First question" }, { role: :assistant, content: "First answer" },
                   { role: :user, content: "NEW SNAPSHOT\n\nMy question: Second question" } ], tutor.send(:history)

    # A reading lesson's tutor is unchanged.
    reading = user.tutor_messages.create!(lesson: lessons(:free_one), role: "user", content: "What is a token?")
    assert_includes Tutor.for(reading).send(:system_prompt), "the AI tutor for the Ironwood Tech course \"Free Course\""
    assert_equal [ { role: :user, content: "What is a token?" } ], Tutor.for(reading).send(:history)
  end

  test "a tutor message belongs to one lesson, and goes when its class lesson goes" do
    lessons_for_everyone
    user = users(:two)
    assert_not user.tutor_messages.new(role: "user", content: "q").valid?
    assert_not user.tutor_messages.new(role: "user", content: "q", lesson: lessons(:free_one), class_lesson: @one).valid?
    assert_not user.tutor_messages.new(role: "user", content: "q", class_lesson: @one, context: "x" * 16_001).valid?
    message = user.tutor_messages.create!(role: "assistant", content: "a", class_lesson: @tour)
    assert_equal [ @tour, "Prof. Example" ], [ message.home, message.tutor_name ]
    assert_difference -> { TutorMessage.count }, -1 do
      @tour.destroy
    end
  end
end
