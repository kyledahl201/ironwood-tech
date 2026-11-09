require "test_helper"

class StudentFlowTest < ActionDispatch::IntegrationTest
  test "public pages render with the disclosure and noindex" do
    %w[/ /courses /courses/free-course /courses/free-course/rubric /about /faq /refunds /privacy /terms /consulting /blog /signup].each do |path|
      get path
      assert_response :success, path
      assert_includes response.body, "not an accredited school", path
      assert_select "meta[name=robots][content='noindex, nofollow']"
    end
  end

  test "sign up, enroll free, finish every lesson, get a certificate" do
    post registration_path, params: { user: { name: "New Person", email_address: "new@example.com", password: "longpassword1", password_confirmation: "longpassword1" } }
    assert_redirected_to portal_url
    course = courses(:free)

    post course_checkout_path(course)
    assert_redirected_to learn_lesson_path(course, 1)
    enrollment = User.find_by!(email_address: "new@example.com").enrollments.find_by!(course: course)
    assert_equal "free", enrollment.source

    get portal_certificate_path(course)
    assert_redirected_to portal_path

    post complete_learn_lesson_path(course, 1)
    assert_redirected_to learn_lesson_path(course, 2)
    post complete_learn_lesson_path(course, 2)
    assert_redirected_to portal_path

    get portal_certificate_path(course)
    assert_response :success
    assert_select ".who", "New Person"
    assert_includes response.body, "marked every lesson complete"
    assert_includes response.body, "not academic credit"
  end

  test "lessons are locked without an enrollment" do
    sign_in_as users(:one)
    get learn_lesson_path(courses(:paid), 1)
    assert_redirected_to course_path(courses(:paid))
  end

  test "paid course without Stripe does not enroll" do
    sign_in_as users(:one)
    post course_checkout_path(courses(:paid))
    assert_redirected_to course_path(courses(:paid))
    assert_not users(:one).enrolled_in?(courses(:paid))
  end

  test "course with no price is not on sale" do
    sign_in_as users(:one)
    get course_path(courses(:unpriced))
    assert_includes response.body, "Price coming soon"
    post course_checkout_path(courses(:unpriced))
    assert_not users(:one).enrolled_in?(courses(:unpriced))
  end

  test "paid course shows price and refund link before checkout" do
    sign_in_as users(:one)
    get course_path(courses(:paid))
    assert_select ".disclosure-box", /\$149/
    assert_select ".disclosure-box a[href=?]", refunds_path
  end

  include ActiveJob::TestHelper

  test "tutor saves the question, answers in the background, and says offline without a key" do
    sign_in_as users(:two)
    lesson = lessons(:free_one)
    assert_difference -> { TutorMessage.count }, 2 do
      assert_enqueued_with(job: TutorReplyJob) do
        post learn_lesson_tutor_messages_path(courses(:free), lesson), params: { tutor_message: { content: "What is a token?" } }, as: :turbo_stream
      end
    end
    assert_response :success
    assert_includes response.body, "What is a token?"
    placeholder = TutorMessage.order(:id).last
    assert placeholder.pending?

    perform_enqueued_jobs
    placeholder.reload
    assert_not placeholder.pending?
    assert_equal Tutor::OFFLINE, placeholder.content
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

  test "newsletter unsubscribe needs a valid signed link and a POST" do
    lead = Lead.create!(kind: "newsletter", email: "reader@example.com")
    get unsubscribe_path(lead.unsubscribe_token)
    assert_response :success
    assert_equal "new", lead.reload.status
    post unsubscribe_path(lead.unsubscribe_token)
    assert_equal "unsubscribed", lead.reload.status
    get unsubscribe_path("forged")
    assert_redirected_to root_path
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
    assert_not_includes response.body, users(:two).name
    get portal_certificate_path(courses(:free))
    assert_response :not_found
  end

  test "newsletter and consulting leads are saved" do
    post leads_path, params: { lead: { kind: "newsletter", email: "News@Example.com " } }
    assert_redirected_to root_path
    post leads_path, params: { lead: { kind: "consulting", name: "Exec", email: "exec@example.com", message: "Pilot" } }
    assert_redirected_to consulting_path
    assert_equal %w[news@example.com exec@example.com], Lead.order(:id).pluck(:email)
  end

  test "owner area is owner-only, and the owner can grant and price courses" do
    sign_in_as users(:one)
    get admin_root_path
    assert_redirected_to root_path

    sign_in_as users(:owner)
    get admin_root_path
    assert_response :success
    post admin_enrollments_path, params: { user_id: users(:one).id, course_id: courses(:paid).id }
    assert_equal "admin", users(:one).enrollments.find_by(course: courses(:paid)).source

    patch admin_course_path(courses(:unpriced)), params: { course: { price_cents: "" } }
    assert_nil courses(:unpriced).reload.price_cents
    patch admin_course_path(courses(:unpriced)), params: { course: { price_cents: "9900" } }
    assert_equal "$99", courses(:unpriced).reload.price
  end
end
