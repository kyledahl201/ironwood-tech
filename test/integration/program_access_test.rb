require "test_helper"

# Programs: what a buyer gets. Owning a program (bought, given by the owner or
# a claimed gift) opens every class in it, and nothing else. Someone without
# it is turned away from its classes. A program with no classes yet is
# "Coming": listed, with no way to buy or claim it.
class ProgramAccessTest < ActionDispatch::IntegrationTest
  setup do
    Program.sync!
    @rails = Program.find_by!(slug: "rails-bootcamp")
    @px1 = Program.find_by!(slug: "life-and-work")
    @boomers = Program.find_by!(slug: "ai-for-boomers")
    attrs = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    @cs090 = ClassLesson.create!(attrs.merge(slug: "zz-p-090", course_code: "CS 090", lesson_number: 1))
    @cs101 = ClassLesson.create!(attrs.merge(slug: "zz-p-101", course_code: "CS 101", lesson_number: 1))
    ClassLesson.create!(attrs.merge(slug: "zz-p-tour", course_code: "TOUR", lesson_number: 1, title: "Made up: the tour"))
    @player = courses(:px1)

    @stranger = User.create!(name: "Nora Nobody", email_address: "nora@example.com", password: "password12345")
    @holder = User.create!(name: "Hal Holder", email_address: "hal@example.com", password: "password12345")
    ProgramEnrollment.grant!(user: @holder, program: @rails, source: "purchase", amount_cents: 4900)
    @px1_student = User.create!(name: "Pia Starter", email_address: "pia@example.com", password: "password12345")
    ProgramEnrollment.grant!(user: @px1_student, program: @px1, source: "admin")
    ActionMailer::Base.deliveries.clear
  end

  def denied?
    return true if [ 401, 403, 404 ].include?(response.status)
    response.redirect? && (flash[:alert].present? || response.location.end_with?(new_session_path))
  end

  def class_routes
    {
      "CS 090 class" => -> { get class_lesson_path(@cs090) },
      "CS 101 class" => -> { get class_lesson_path(@cs101) },
      "CS 101 progress" => -> { post progress_class_lesson_path(@cs101), params: { step_index: 1 }, as: :json },
      "CS 101 study guide" => -> { get study_class_lesson_path(@cs101) }
    }
  end

  def main_text = css_select("main").text.squish

  test "the holder of a program opens every class in it; everyone else is turned away" do
    sign_in_as @holder
    class_routes.each do |name, request|
      request.call
      assert_not denied?, "#{name}: the program's holder is let in (got #{response.status})"
    end
    get course_player_path(@player)
    assert denied?, "a class in another program stays closed"

    [ @stranger, @px1_student ].each do |user|
      sign_in_as user
      class_routes.each do |name, request|
        request.call
        assert denied?, "#{name}: #{user.name} doesn't hold the program (got #{response.status})"
      end
    end
    sign_out
    get class_lesson_path(@cs101)
    assert_redirected_to new_session_path

    sign_in_as users(:owner)
    class_routes.each do |name, request|
      request.call
      assert_not denied?, "#{name}: the site's owner opens everything"
    end
  end

  test "a student holding only PX1 opens its class, sees it as theirs, and nothing else is open" do
    sign_in_as @px1_student
    get course_player_path(@player)
    assert_response :success
    get programs_path
    assert_response :success
    assert_select "#life-and-work .pill-owned", text: "Yours"
    assert_select "#life-and-work .course-pick a.btn[href=?]", course_player_path(@player), text: /Open/
    assert_select "#rails-bootcamp .pill-owned", 0
    assert_select "#rails-bootcamp .course-pick .course-state", text: "Comes with the program", count: 2
    assert_select "#rails-bootcamp .course-pick a.btn", 0
    get program_path(@px1)
    assert_select ".buy-box", text: /This program is yours/
  end

  test "the owner gifts a whole program by email, and claiming it opens every class in it" do
    sign_in_as users(:owner)
    get admin_gifts_path
    assert_select "select[name=gift_for] optgroup[label='Programs (every class in it)'] option[value=?]", "program:#{@rails.id}", text: /Engineering \/ Rails Bootcamp \(PX2 · 2 classes\)/
    assert_select "select[name=gift_for] option[value=?]", "program:#{@boomers.id}", 0 # Coming: nothing to give yet

    post admin_gifts_path, params: { gift_for: "program:#{@rails.id}", recipient_email: "friend@example.com" }
    assert_redirected_to admin_gifts_path
    gift = Gift.last
    assert_equal [ @rails, nil ], [ gift.program, gift.course ]
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Ironwood Tech gave you Engineering / Rails Bootcamp", mail.subject
    assert_includes mail.text_part.body.to_s, "a program: Engineering / Rails Bootcamp (every class in it)"
    token = mail.text_part.body.to_s[%r{/gift/([A-Za-z0-9_-]+)}, 1]

    sign_out
    get gift_claim_path(token)
    assert_select "h1", text: "Engineering / Rails Bootcamp"
    post registration_path(gift: token), params: { user: { name: "Gale Giftee", email_address: "friend@example.com", password: "longpassword1", password_confirmation: "longpassword1" } }
    friend = User.find_by!(email_address: "friend@example.com")
    assert_not friend.can_open?(courses(:cs101)), "making the account isn't claiming"
    post redeem_gift_path(token)
    assert_redirected_to program_path(@rails)
    assert_match(/every class in it/, flash[:notice])
    assert friend.reload.holds_program?(@rails)
    class_routes.each do |name, request|
      request.call
      assert_not denied?, "#{name}: the gift opened it"
    end

    # Ending the gift ends the program and the classes it gave.
    sign_in_as users(:owner)
    post revoke_admin_gift_path(gift)
    assert_not friend.reload.holds_program?(@rails)
    assert_not friend.can_open?(courses(:cs090))
    assert_not friend.can_open?(courses(:cs101))
  end

  test "a program that's Coming shows Coming, and has no way to buy, claim or give it" do
    @boomers.update!(price_cents: 1900) # even with a price
    get programs_path
    assert_response :success
    assert_select "#ai-for-boomers .pill-coming", text: "Coming"
    assert_select "#ai-for-boomers a.btn, #ai-for-boomers form, #ai-for-boomers button", 0
    assert_select "#ai-for-boomers", text: /\$19/, count: 0

    get program_path(@boomers)
    assert_response :success
    assert_select ".buy-box .pill-coming", text: "Coming"
    assert_select ".buy-box a.btn, .buy-box form, .buy-box button", 0

    with_stripe do
      sign_in_as @stranger
      stub_method(Payments, :create_session, ->(**) { flunk "a Coming program reached Stripe" }) do
        post checkout_program_path(@boomers), params: { accept_terms: "1" }
      end
      assert_redirected_to program_path(@boomers)
      assert_match(/can't be bought yet/, flash[:alert])
    end

    sign_in_as users(:owner)
    assert_no_difference -> { Gift.count } do
      post admin_gifts_path, params: { gift_for: "program:#{@boomers.id}", recipient_email: "friend@example.com" }
    end
    post admin_program_enrollments_path, params: { user_id: @stranger.id, program_id: @boomers.id }
    assert_not @stranger.holds_program?(@boomers)
  end

  test "the Programs page is public: three tiers, Start here, and no price until one is set" do
    get programs_path
    assert_response :success
    assert_select "nav a[href=?]", programs_path, text: "Programs"
    assert_equal [ "Start here", "Everyday AI", "AI at Work", "Build with AI" ], css_select("main h2").map { |h| h.text.squish }.reject { |t| t.blank? }.first(4)
    assert_select "#life-and-work .pill", text: "Price coming"
    assert_select "#life-and-work a.btn[href=?]", program_path(@px1), text: /See the program/
    assert_no_match(/\$\d/, main_text)
    assert_no_match(/PX1|PYX|PX2/, main_text, "the tier codes are internal")
    assert_no_match(/universit|institut|college|academy|degree|credit|certificat|enroll/i, main_text)
    assert_includes main_text, "AI school"

    get program_path(@rails)
    assert_response :success
    assert_select ".crumbs a[href=?]", programs_path
    assert_select ".buy-box .price", text: "Price coming"
    assert_select ".buy-box a.btn, .buy-box form", 0
    assert_select ".course-pick .course-name a", text: "Computing Orientation"
    assert_select ".course-pick a[href^='/classroom/']", 0
    content = css_select(".page-head, .course-layout > div").text.squish
    assert_no_match(/universit|institut|college|academy|degree|credit|certificat|enroll|job|salary|income|hired/i, content)

    @rails.update!(price_cents: 4900)
    get programs_path
    assert_select "#rails-bootcamp .program-price", text: "$49"
    with_stripe do
      get program_path(@rails)
      assert_select ".buy-box a.btn[href=?]", new_registration_path(program: @rails.slug), text: "Buy for $49"
    end
  end

  test "buying a program through Stripe opens every class, and a refund closes them again" do
    @rails.update!(price_cents: 4900)
    buyer = @stranger
    with_stripe do
      sign_in_as buyer
      asked = nil
      stub_method(Payments, :create_session, ->(**args) { asked = args; Struct.new(:url).new("https://checkout.stripe.com/c/pay/cs_prog_1") }) do
        post checkout_program_path(@rails), params: { accept_terms: "1" }
      end
      assert_redirected_to "https://checkout.stripe.com/c/pay/cs_prog_1"
      assert_equal [ @rails, nil, buyer ], [ asked[:program], asked[:course], asked[:user] ]
      assert_not buyer.can_open?(courses(:cs101)), "nothing until Stripe says it's paid"

      data = { id: "cs_prog_1", object: "checkout.session", payment_status: "paid", amount_total: 4900, payment_intent: "pi_prog_1",
               metadata: { user_id: buyer.id.to_s, program_id: @rails.id.to_s, terms_accepted_at: Time.current.iso8601 } }
      post_webhook(stripe_event("checkout.session.completed", data))
      assert_response :success
      pe = buyer.program_enrollments.find_by!(program: @rails)
      assert_equal [ "purchase", 4900, "pi_prog_1" ], [ pe.source, pe.amount_cents, pe.payment_intent_id ]
      assert buyer.reload.can_open?(courses(:cs090))
      assert buyer.can_open?(courses(:cs101))

      paid = Stripe::Checkout::Session.construct_from(data)
      stub_method(Payments, :retrieve_session, ->(_id) { paid }) do
        get checkout_success_program_path(@rails, session_id: "cs_prog_1")
      end
      assert_redirected_to program_path(@rails)
      assert_match(/is yours, with every class in it/, flash[:notice])
      assert_equal 1, buyer.program_enrollments.count, "the success page and the webhook make one"

      post_webhook(stripe_event("charge.refunded", { id: "ch_1", object: "charge", payment_intent: "pi_prog_1", refunded: true }))
      assert_not pe.reload.active?
      assert_not buyer.reload.can_open?(courses(:cs090))
      assert_not buyer.can_open?(courses(:cs101))

      # A replay of the paid event doesn't give it back.
      post_webhook(stripe_event("checkout.session.completed", data))
      assert_not buyer.reload.can_open?(courses(:cs101))
    end
  end

  test "the owner gives a program on a student's page, and can end it" do
    sign_in_as users(:owner)
    get admin_user_path(@stranger)
    assert_select "select[name=program_id] option", text: "Engineering / Rails Bootcamp (PX2)"
    post admin_program_enrollments_path, params: { user_id: @stranger.id, program_id: @rails.id }
    assert_redirected_to admin_user_path(@stranger)
    assert @stranger.reload.can_open?(courses(:cs101))
    pe = @stranger.program_enrollments.last
    post revoke_admin_program_enrollment_path(pe)
    assert_not @stranger.reload.can_open?(courses(:cs101))
    post reinstate_admin_program_enrollment_path(pe)
    assert @stranger.reload.can_open?(courses(:cs101))

    get admin_programs_path
    assert_response :success
    assert_select "td", text: "Coming (none yet)", minimum: 1
    patch admin_program_path(@px1), params: { program: { price_cents: "2900" } }
    assert_equal 2900, @px1.reload.price_cents
  end

  test "existing course owners keep their classes, and see the program as theirs" do
    sign_in_as users(:two) # given CS 090 and CS 101 before programs existed (fixtures)
    get class_lesson_path(@cs101)
    assert_response :success
    get programs_path
    assert_select "#rails-bootcamp .pill-owned", text: "Yours"
    assert_not users(:two).holds_program?(@rails)
  end
end
