require "test_helper"

class StudentFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "public pages show the disclosure, claim no non-profit status and are not indexed" do
    %w[/ /privacy /terms /refunds /store /session/new].each do |path|
      get path
      assert_response :success, path
      assert_includes response.body, "not an accredited school", path
      assert_includes response.body, "AI personas", path
      assert_no_match(/non-?profit|sells nothing|invitation only/i, response.body, path)
      assert_select "meta[name=robots][content='noindex, nofollow']"
    end
    get root_path
    assert_no_match(/\$\d|enroll now|buy/i, response.body)
  end

  test "everything else needs a sign-in" do
    %w[/portal /courses /lab /visualizers /visualizers/loop /portal/badges /portal/study-log].each do |path|
      get path
      assert_redirected_to new_session_path, path
    end
  end

  test "sign-up is invite-only and an invite works once" do
    get new_registration_path
    assert_response :forbidden
    params = { user: { name: "New Friend", email_address: "friend@example.com", password: "longpassword1", password_confirmation: "longpassword1" } }
    assert_no_difference -> { User.count } do
      post registration_path, params: params
      post registration_path, params: params.merge(invite: "forged")
    end

    invite = Invite.create!(created_by: users(:owner))
    get new_registration_path(invite: invite.token)
    assert_response :success
    assert_difference -> { User.count }, 1 do
      post registration_path, params: params.merge(invite: invite.token)
    end
    assert_redirected_to portal_url
    assert_equal "friend@example.com", invite.reload.used_by.email_address

    sign_out
    assert_no_difference -> { User.count } do
      post registration_path, params: { invite: invite.token, user: params[:user].merge(email_address: "second@example.com") }
    end
  end

  test "expired invites do not work" do
    invite = Invite.create!(created_by: users(:owner), expires_at: 1.day.ago)
    get new_registration_path(invite: invite.token)
    assert_response :forbidden
  end

  test "start a course, finish every lesson, get a certificate" do
    sign_in_as users(:one)
    course = courses(:free)
    post course_enrollment_path(course)
    assert_redirected_to learn_lesson_path(course, 1)
    assert_equal "self", users(:one).enrollments.find_by!(course: course).source

    get portal_certificate_path(course)
    assert_redirected_to portal_path
    post complete_learn_lesson_path(course, 1)
    post complete_learn_lesson_path(course, 2)
    assert_redirected_to portal_path
    assert users(:one).user_badges.exists?(key: "course_done")

    get portal_certificate_path(course)
    assert_response :success
    assert_includes response.body, "not academic credit"
  end

  test "lessons are locked without an enrollment" do
    sign_in_as users(:one)
    get learn_lesson_path(courses(:other), 1)
    assert_redirected_to course_path(courses(:other))
  end

  test "tutor saves the question, answers in the background, and says offline without a key" do
    sign_in_as users(:two)
    lesson = lessons(:free_one)
    assert_difference -> { TutorMessage.count }, 2 do
      assert_enqueued_with(job: TutorReplyJob) do
        post learn_lesson_tutor_messages_path(courses(:free), lesson), params: { tutor_message: { content: "What is a token?" } }, as: :turbo_stream
      end
    end
    assert_response :success
    placeholder = TutorMessage.order(:id).last
    assert placeholder.pending?
    perform_enqueued_jobs
    assert_equal Tutor::OFFLINE, placeholder.reload.content
  end

  test "tutor stops at the daily cap without calling the model" do
    sign_in_as users(:two)
    lesson = lessons(:free_one)
    Tutor.daily_cap(courses(:free)).times { users(:two).tutor_messages.create!(lesson: lesson, role: "user", content: "q") }
    assert_no_difference -> { TutorMessage.count } do
      assert_no_enqueued_jobs do
        post learn_lesson_tutor_messages_path(courses(:free), lesson), params: { tutor_message: { content: "one more" } }
      end
    end
    assert_match(/today's \d+ tutor questions/, flash[:alert])
  end

  test "expired tutor chats are purged" do
    old = TutorMessage.create!(user: users(:two), lesson: lessons(:free_one), role: "user", content: "old", created_at: 400.days.ago)
    fresh = TutorMessage.create!(user: users(:two), lesson: lessons(:free_one), role: "user", content: "new")
    PurgeExpiredTutorMessagesJob.perform_now
    assert_not TutorMessage.exists?(old.id)
    assert TutorMessage.exists?(fresh.id)
  end

  test "tutor replies render markdown without raw HTML" do
    sign_in_as users(:two)
    TutorMessage.create!(user: users(:two), lesson: lessons(:free_one), role: "assistant", content: "**bold** <script>alert(1)</script>")
    get learn_lesson_path(courses(:free), 1)
    assert_select ".msg strong", "bold"
    assert_not_includes response.body, "<script>alert(1)</script>"
  end

  test "a student's record is private to them" do
    sign_in_as users(:one)
    get portal_path
    assert_response :success
    assert_not_includes response.body, users(:two).name
    get portal_certificate_path(courses(:free))
    assert_response :not_found
  end

  test "owner area is owner-only" do
    sign_in_as users(:one)
    %w[/admin /admin/invites /admin/transcript /admin/exercises /admin/users].each do |path|
      get path
      assert_redirected_to root_path, path
    end
    post admin_invites_path
    assert_equal 0, Invite.count

    sign_in_as users(:owner)
    %w[/admin /admin/invites /admin/transcript /admin/exercises /admin/users /admin/courses].each do |path|
      get path
      assert_response :success, path
    end
    post admin_invites_path, params: { invite: { note: "A friend" } }
    assert_equal 1, Invite.open.count
    get admin_invites_path
    assert_includes response.body, Invite.last.token
    post admin_enrollments_path, params: { user_id: users(:one).id, course_id: courses(:other).id }
    assert_equal "admin", users(:one).enrollments.find_by(course: courses(:other)).source
  end
end
