require "test_helper"

class PaymentsTest < ActionDispatch::IntegrationTest
  FakeSession = Struct.new(:id, :payment_status, :metadata, :amount_total, :payment_intent, keyword_init: true)
  FakeObject = Struct.new(:id, :payment_intent, :refunded, keyword_init: true)
  FakeEvent = Struct.new(:type, :data)

  def with_fake_stripe(session)
    fake_sessions = Object.new
    fake_sessions.define_singleton_method(:retrieve) { |_id| session }
    fake_client = Struct.new(:v1).new(Struct.new(:checkout).new(Struct.new(:sessions).new(fake_sessions)))
    ENV["STRIPE_SECRET_KEY"] = "sk_test_fake"
    original = Payments.method(:client)
    Payments.define_singleton_method(:client) { fake_client }
    yield
  ensure
    Payments.define_singleton_method(:client, original) if original
    ENV.delete("STRIPE_SECRET_KEY")
  end

  def paid_session(id:, user: users(:one), course: courses(:paid), pi: "pi_#{id}", status: "paid")
    FakeSession.new(id: id, payment_status: status, amount_total: 14900, payment_intent: pi,
                    metadata: { "user_id" => user.id.to_s, "course_id" => course.id.to_s, "terms_accepted_at" => "2026-11-09T07:00:00Z" })
  end

  def event(type, **obj) = FakeEvent.new(type, Struct.new(:object).new(FakeObject.new(**obj)))

  test "fulfill enrolls once for a paid session and ignores unpaid ones" do
    with_fake_stripe(paid_session(id: "cs_1")) { 2.times { Payments.fulfill("cs_1") } }
    e = users(:one).enrollments.find_by!(course: courses(:paid))
    assert_equal [ "stripe", 14900, "cs_1", "pi_cs_1" ], [ e.source, e.amount_cents, e.stripe_session_id, e.payment_intent_id ]
    assert e.terms_accepted_at

    with_fake_stripe(paid_session(id: "cs_2", user: users(:two), status: "unpaid")) { assert_nil Payments.fulfill("cs_2") }
    assert_not users(:two).enrolled_in?(courses(:paid))
  end

  test "fulfill refuses a session that belongs to another user" do
    with_fake_stripe(paid_session(id: "cs_3")) { assert_nil Payments.fulfill("cs_3", expected_user: users(:two)) }
  end

  test "a full refund or a dispute ends access, and a replayed event does not restore it" do
    with_fake_stripe(paid_session(id: "cs_4")) { Payments.fulfill("cs_4") }
    assert users(:one).enrolled_in?(courses(:paid))

    Payments.handle_event(event("charge.refunded", payment_intent: "pi_cs_4", refunded: false))
    assert users(:one).enrolled_in?(courses(:paid)), "partial refund keeps access"

    Payments.handle_event(event("charge.refunded", payment_intent: "pi_cs_4", refunded: true))
    assert_not users(:one).enrolled_in?(courses(:paid))
    assert_equal "refunded", users(:one).enrollments.find_by(course: courses(:paid)).revoke_reason

    with_fake_stripe(paid_session(id: "cs_4")) { Payments.fulfill("cs_4") }
    assert_not users(:one).enrolled_in?(courses(:paid)), "replay of the refunded checkout"

    with_fake_stripe(paid_session(id: "cs_5")) { Payments.fulfill("cs_5") }
    assert users(:one).enrolled_in?(courses(:paid)), "a new purchase restores access"

    Payments.handle_event(event("charge.dispute.created", payment_intent: "pi_cs_5"))
    assert_not users(:one).enrolled_in?(courses(:paid))

    sign_in_as users(:one)
    get learn_lesson_path(courses(:paid), 1)
    assert_redirected_to course_path(courses(:paid))
  end

  test "paid checkout requires accepting the terms" do
    sign_in_as users(:one)
    ENV["STRIPE_SECRET_KEY"] = "sk_test_fake"
    post course_checkout_path(courses(:paid))
    assert_redirected_to course_path(courses(:paid))
    assert_match(/terms and refund policy/, flash[:alert])
  ensure
    ENV.delete("STRIPE_SECRET_KEY")
  end

  test "webhook rejects a bad signature" do
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test"
    post "/webhooks/stripe", params: "{}", headers: { "Stripe-Signature" => "bad", "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
  ensure
    ENV.delete("STRIPE_WEBHOOK_SECRET")
  end
end
