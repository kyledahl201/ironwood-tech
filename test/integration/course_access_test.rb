require "test_helper"

# Every course is owned or closed. For each place course content lives, the
# people who don't own the course are turned away, and the student who owns
# it and the site's owner get in:
#
#   * a signed-out visitor
#   * a signed-in invited student who owns nothing
#   * an account made by buying a different course (customer only)
#   * a buyer whose purchase was refunded
#   * a student who owns the course (claimed a gift, given by the owner, bought it)
#   * the owner of the site (admin), who opens everything
class CourseAccessTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    attrs = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    @lesson = ClassLesson.create!(attrs.merge(slug: "zz-access", course_code: "CS 101", lesson_number: 1))
    @quiz_step = @lesson.steps.index { |s| s["kind"] == "quiz" }
    @kit_lesson = ClassLesson.create!(attrs.merge(slug: "zz-access-ai", course_code: "AI 360", lesson_number: 1))
    @exercise = exercises(:first) # CS 101, lesson 1
    @reading = courses(:free)
    @player = courses(:px1)
    @classroom = courses(:cs101)
    @kit_course = courses(:ai360)
    @kit = TutorKit.for("AI 360")

    @stranger = User.create!(name: "Nora Nobody", email_address: "nora@example.com", password: "password12345")
    @customer = users(:customer)
    @customer.enrollments.create!(course: courses(:unpriced), source: "purchase") # bought a different course
    @refunded = User.create!(name: "Rae Refunded", email_address: "rae@example.com", password: "password12345")
    @owner_student = User.create!(name: "Olive Owner", email_address: "olive@example.com", password: "password12345")
    @admin = users(:owner)

    [ @classroom, @kit_course, @reading, @player ].each do |course|
      @refunded.enrollments.create!(course: course, source: "purchase", revoked_at: 1.day.ago, revoke_reason: "refunded")
    end
    @owner_student.enrollments.create!(course: @classroom, source: "gift")
    @owner_student.enrollments.create!(course: @kit_course, source: "admin")
    @owner_student.enrollments.create!(course: @reading, source: "admin")
    @owner_student.enrollments.create!(course: @player, source: "purchase")

    # The class is finished, so homework and the lab exercise it teaches are open to whoever owns the course.
    [ @owner_student, @admin, @stranger, @refunded, @customer ].each do |user|
      ClassProgress.create!(user: user, class_lesson: @lesson, step_index: @lesson.steps.size, completed_at: Time.current, quiz_first: { @quiz_step.to_s => true })
    end
  end

  # Each place course content lives, as one request.
  def content_routes
    {
      "classroom lesson" => -> { get class_lesson_path(@lesson) },
      "classroom progress" => -> { post progress_class_lesson_path(@lesson), params: { step_index: 1 }, as: :json },
      "classroom quiz" => -> { post quiz_class_lesson_path(@lesson), params: { step: @quiz_step, choice: 0 }, as: :json },
      "study guide and flashcards" => -> { get study_class_lesson_path(@lesson) },
      "flashcard sort" => -> { post study_card_class_lesson_path(@lesson), params: { card: 0, result: "known" }, as: :json },
      "study restart" => -> { post study_restart_class_lesson_path(@lesson), params: { what: "deck" }, as: :json },
      "homework" => -> { get homework_class_lesson_path(@lesson) },
      "homework hand-in" => -> { post homework_class_lesson_path(@lesson), params: { task_index: 0, work: "x = 1" }, as: :json },
      "class tutor" => -> { post class_lesson_tutor_messages_path(@lesson), params: { tutor_message: { content: "Why?" } }, as: :turbo_stream },
      "tutor kit" => -> { get tutor_kit_path(@kit.slug) },
      "tutor kit file" => -> { get tutor_kit_file_path(@kit.slug, "README.md") },
      "lab exercise" => -> { get exercise_path(@exercise) },
      "lab attempt" => -> { post exercise_attempts_path(@exercise), params: { code: "puts 45", passed: true, checks_passed: 1 }, as: :json },
      "reading lesson" => -> { get learn_lesson_path(@reading, 1) },
      "reading lesson complete" => -> { post complete_learn_lesson_path(@reading, 1) },
      "reading tutor" => -> { post learn_lesson_tutor_messages_path(@reading, lessons(:free_one)), params: { tutor_message: { content: "Why?" } } },
      "rubric" => -> { get rubric_course_path(@reading) },
      "course player" => -> { get course_player_path(@player) },
      "player downloads" => -> { get course_downloads_path(@player) }
    }
  end

  def denied?
    return true if [ 401, 403, 404 ].include?(response.status)
    return false unless response.redirect?
    flash[:alert].present? || response.location.end_with?(new_session_path) || response.location.end_with?(store_path)
  end

  def assert_route(name, allowed:, who:)
    content_routes.fetch(name).call
    if allowed
      assert_not denied?, "#{who} should open #{name} (got #{response.status} #{response.location} #{flash[:alert]})"
      assert response.successful? || response.redirect?, "#{who}: #{name} gave #{response.status}"
    else
      assert denied?, "#{who} should not open #{name} (got #{response.status})"
      assert_no_match(/Lesson one body|First hint\.|Point one\./, response.body.to_s, "#{who}: #{name} showed course content")
    end
  end

  test "a signed-out visitor is sent to sign in from every course page" do
    content_routes.each_key do |name|
      content_routes.fetch(name).call
      assert_redirected_to new_session_path, name
    end
  end

  test "an invited student who owns nothing is turned away everywhere" do
    sign_in_as @stranger
    content_routes.each_key { |name| assert_route(name, allowed: false, who: "a student who owns nothing") }
  end

  test "an account that bought a different course is turned away everywhere" do
    sign_in_as @customer
    content_routes.each_key { |name| assert_route(name, allowed: false, who: "a buyer of another course") }
  end

  test "a refunded buyer is turned away everywhere" do
    sign_in_as @refunded
    content_routes.each_key { |name| assert_route(name, allowed: false, who: "a refunded buyer") }
  end

  test "a student who owns the course gets in everywhere" do
    sign_in_as @owner_student
    content_routes.each_key { |name| assert_route(name, allowed: true, who: "an owner") }
  end

  test "the owner of the site gets in everywhere, owning nothing" do
    sign_in_as @admin
    assert_empty @admin.enrollments.active
    content_routes.each_key { |name| assert_route(name, allowed: true, who: "the admin") }
  end

  test "a certificate needs the course, owned and finished" do
    @reading.lessons.each { |l| @owner_student.enrollments.find_by!(course: @reading).lesson_completions.create!(lesson: l) }
    sign_in_as @owner_student
    get portal_certificate_path(@reading)
    assert_response :success

    [ @stranger, @refunded ].each do |user|
      sign_in_as user
      get portal_certificate_path(@reading)
      assert_response :not_found
    end
  end

  test "course pages and lists show a course that isn't owned only by its title and description" do
    sign_in_as @stranger
    get course_path("cs-101")
    assert_response :success
    assert_select "h1", text: "Intro to Programming in Ruby"
    assert_includes response.body, "You don't have this course yet."
    assert_select "a[href=?]", class_lesson_path(@lesson), 0
    assert_select "a[href=?]", study_class_lesson_path(@lesson), 0
    assert_select "a[href^='/classroom/kits']", 0

    get course_path(@reading)
    assert_select "a[href=?]", learn_lesson_path(@reading, 1), 0
    assert_select "a[href=?]", rubric_course_path(@reading), 0
    assert_no_match(/First lesson/, response.body)

    get courses_path
    assert_select ".course-pick a[href^='/classroom/'], .course-pick a[href^='/learn/']", 0
    assert_select ".course-pick .course-state", text: "Not yours yet", minimum: 1
    assert_select ".course-pick form", 0

    get class_lessons_path
    assert_response :success
    assert_includes response.body, "Your classroom opens with your first course"
    assert_select "a[href=?]", class_lesson_path(@lesson), 0

    get exercises_path
    assert_select "a[href=?]", exercise_path(@exercise), 0
    assert_no_match(/#{@exercise.title}/, response.body)

    get portal_path
    assert_response :success
    assert_select "a[href=?]", class_lesson_path(@lesson), 0
    assert_select "a[href=?]", exercise_path(@exercise), 0
  end

  test "the owner of a course sees it in the lists with a way in" do
    sign_in_as @owner_student
    get courses_path
    assert_select ".course-pick a.btn[href=?]", class_lesson_path(@lesson)
    get course_path("cs-101")
    assert_select "a[href=?]", class_lesson_path(@lesson)
    get exercises_path
    assert_select "a[href=?]", exercise_path(@exercise)
  end

  test "an account made by claiming a gift can use the classroom course it owns, and nothing else of the portal" do
    @customer.enrollments.create!(course: @classroom, source: "gift")
    sign_in_as @customer
    get class_lesson_path(@lesson)
    assert_response :success
    get courses_path
    assert_response :success
    assert_select "nav a[href=?]", class_lessons_path
    %w[/portal /portal/study-log /visualizers].each do |path|
      get path
      assert_redirected_to store_path, path
    end
  end

  test "no one can start a course by themselves any more" do
    sign_in_as @stranger
    post "/courses/#{@reading.slug}/enrollment"
    assert_response :not_found
    assert_not @stranger.enrolled_in?(@reading)
    assert_not Rails.application.routes.url_helpers.respond_to?(:course_enrollment_path)
  end

  test "the owner opens a reading course with no enrollment of their own, and their progress is kept" do
    sign_in_as @admin
    post complete_learn_lesson_path(@reading, 1)
    enrollment = @admin.enrollments.find_by!(course: @reading)
    assert_equal "admin", enrollment.source
    assert_equal 1, enrollment.lesson_completions.count
  end

  test "every classroom course code in the seeds gets a Course to own, and running it twice changes nothing" do
    ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("lesson.md").read).merge(slug: "zz-new-code", course_code: "ZZ 123", lesson_number: 1))
    Course.where(code: "CS 090").destroy_all
    Enrollment.where(course: courses(:cs090)).delete_all
    courses(:cs090).destroy
    ClassLesson.create!(ClassLessonMarkdown.parse(file_fixture("lesson.md").read).merge(slug: "zz-cs090", course_code: "CS 090", lesson_number: 1))

    assert_difference -> { Course.count }, 2 do
      Catalog.sync_courses!
    end
    assert_no_difference -> { Course.count } do
      Catalog.sync_courses!
    end
    cs090 = Course.find_by!(code: "CS 090")
    assert_equal [ "cs-090", "Computing Orientation", false, true ], [ cs090.slug, cs090.title, cs090.paid?, cs090.published? ]
    assert_equal "zz-123", Course.find_by!(code: "ZZ 123").slug
    assert_empty cs090.enrollments, "nobody is given anything"
  end
end
