require "test_helper"

# Gifts: a course bought for someone else, or given by the owner, claimed with
# a one-time emailed link. No test talks to Stripe or sends real email.
class GiftsTest < ActionDispatch::IntegrationTest
  setup do
    @course = courses(:px1)
    @buyer = users(:customer)
    ActionMailer::Base.deliveries.clear
  end

  def gift_session(id: "cs_gift_1", payment_intent: "pi_gift_1", to: "friend@example.com")
    data = checkout_session_data(user: @buyer, course: @course, id: id, payment_intent: payment_intent)
    data[:metadata][:gift_recipient] = to
    data
  end

  def claim_token(mail)
    mail.text_part.body.to_s[%r{/gift/([A-Za-z0-9_-]+)}, 1]
  end

  def new_account(email)
    { user: { name: "Gale Giftee", email_address: email, password: "longpassword1", password_confirmation: "longpassword1" } }
  end

  test "the store offers a gift, and checkout sends the recipient to Stripe without giving the buyer anything" do
    with_stripe do
      sign_in_as @buyer
      get store_course_path(@course)
      assert_select "input[type=checkbox][name=gift][value='1']"
      assert_select "input[type=email][name=gift_email]"

      stub_method(Payments, :create_session, ->(**) { flunk "a gift with no email reached Stripe" }) do
        post store_checkout_path(@course), params: { accept_terms: "1", gift: "1", gift_email: "not an email" }
      end
      assert_match(/email address of the person/, flash[:alert])

      asked = nil
      stub_method(Payments, :create_session, ->(**args) { asked = args; Struct.new(:url).new("https://checkout.stripe.com/c/pay/cs_gift_1") }) do
        post store_checkout_path(@course), params: { accept_terms: "1", gift: "1", gift_email: " Friend@Example.com " }
      end
      assert_redirected_to "https://checkout.stripe.com/c/pay/cs_gift_1"
      assert_equal "friend@example.com", asked[:gift_to]
    end
  end

  test "someone who already has the course can still buy it as a gift" do
    @buyer.enrollments.create!(course: @course, source: "purchase")
    with_stripe do
      sign_in_as @buyer
      get store_course_path(@course)
      assert_select "details input[type=hidden][name=gift][value='1']"
      stub_method(Payments, :create_session, ->(**) { Struct.new(:url).new("https://checkout.stripe.com/c/pay/x") }) do
        post store_checkout_path(@course), params: { accept_terms: "1", gift: "1", gift_email: "friend@example.com" }
      end
      assert_redirected_to "https://checkout.stripe.com/c/pay/x"
    end
  end

  test "a paid gift emails the recipient, the buyer gets nothing, and the link works once for anyone" do
    with_stripe do
      assert_difference -> { Gift.count }, 1 do
        post_webhook stripe_event("checkout.session.completed", gift_session)
        post_webhook stripe_event("checkout.session.completed", gift_session) # Stripe sends it again
      end
      assert_response :ok
      gift = Gift.last
      assert_equal [ @course, @buyer, "friend@example.com", 2900, "pi_gift_1" ], [ gift.course, gift.purchaser, gift.recipient_email, gift.amount_cents, gift.payment_intent_id ]
      assert_not @buyer.enrolled_in?(@course), "the buyer doesn't get the course"
      assert gift.emailed_at

      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = ActionMailer::Base.deliveries.last
      assert_equal [ "friend@example.com" ], mail.to
      assert_equal "Casey Customer gave you #{@course.title}", mail.subject
      token = claim_token(mail)
      assert token.present?
      assert_nil Gift.find_by(token_digest: token), "only a digest of the token is stored"
      assert_equal gift, Gift.find_by_token(token)
      assert_no_match(/enroll|university|college|academy|degree/i, mail.text_part.body.to_s)

      # Signed out: the page offers an account or sign-in; nothing is claimed by looking.
      get gift_claim_path(token)
      assert_response :success
      assert_select "h1", text: @course.title
      assert_select "a[href=?]", new_registration_path(gift: token), text: "Make an account"
      assert_select "a[href=?]", new_session_path(return_to: gift_claim_path(token)), text: "Sign in"
      post redeem_gift_path(token)
      assert_redirected_to new_session_path

      # A new account made from the link is a buyer-style account. The email doesn't have to match.
      get new_registration_path(gift: token)
      assert_response :success
      assert_difference -> { User.count }, 1 do
        post registration_path(gift: token), params: new_account("forwarded@example.com")
      end
      assert_redirected_to gift_claim_path(token)
      giftee = User.find_by!(email_address: "forwarded@example.com")
      assert giftee.customer_only?

      post redeem_gift_path(token)
      assert_redirected_to store_course_path(@course)
      enrollment = giftee.enrollments.find_by!(course: @course)
      assert_equal [ "gift", gift ], [ enrollment.source, enrollment.gift ]
      assert_equal giftee, gift.reload.redeemed_by
      assert gift.redeemed_at
      get course_player_path(@course)
      assert_response :success

      # The link works once.
      sign_in_as users(:one)
      post redeem_gift_path(token)
      assert_not users(:one).enrolled_in?(@course)
      get gift_claim_path(token)
      assert_select "h1", text: "This gift has been claimed"
      sign_out
      post registration_path(gift: token), params: new_account("third@example.com")
      assert_response :forbidden
    end
  end

  test "the success page tells the buyer the gift was sent" do
    with_stripe do
      sign_in_as @buyer
      paid = Stripe::Checkout::Session.construct_from(gift_session)
      stub_method(Payments, :retrieve_session, ->(_id) { paid }) do
        get store_checkout_success_path(@course, session_id: "cs_gift_1")
      end
      assert_redirected_to store_course_path(@course)
      assert_match(/We emailed friend@example.com a link/, flash[:notice])
      assert_not @buyer.enrolled_in?(@course)
    end
  end

  test "a refund or dispute ends the gift, and the access it gave" do
    with_stripe do
      post_webhook stripe_event("checkout.session.completed", gift_session)
      token = claim_token(ActionMailer::Base.deliveries.last)
      sign_in_as users(:two)
      post redeem_gift_path(token)
      assert users(:two).enrolled_in?(@course)

      post_webhook stripe_event("charge.refunded", { id: "ch_g", object: "charge", payment_intent: "pi_gift_1", refunded: true })
      assert_not users(:two).enrolled_in?(@course)
      assert_equal [ :revoked, "refunded" ], [ Gift.last.status, Gift.last.revoke_reason ]
      get course_player_path(@course)
      assert_redirected_to store_course_path(@course)

      # An unclaimed gift that's disputed can't be claimed afterwards.
      post_webhook stripe_event("checkout.session.completed", gift_session(id: "cs_gift_2", payment_intent: "pi_gift_2", to: "other@example.com"))
      token2 = claim_token(ActionMailer::Base.deliveries.last)
      post_webhook stripe_event("charge.dispute.created", { id: "dp_g", object: "dispute", payment_intent: "pi_gift_2" })
      sign_in_as users(:one)
      post redeem_gift_path(token2)
      assert_not users(:one).enrolled_in?(@course)
      get gift_claim_path(token2)
      assert_select "h1", text: "This gift is no longer available"
    end
  end

  test "an expired link can't be claimed, and a made-up one is not found" do
    gift = Gift.create!(course: courses(:free), recipient_email: "late@example.com", created_by: users(:owner))
    token = gift.token
    gift.update!(expires_at: 1.minute.ago)
    sign_in_as users(:one)
    post redeem_gift_path(token)
    assert_not users(:one).enrolled_in?(courses(:free))
    get gift_claim_path(token)
    assert_select "h1", text: "This gift link has ended"

    get gift_claim_path("made-up-token-that-is-long-enough")
    assert_response :not_found
    get gift_claim_path("short")
    assert_response :not_found
  end

  test "someone who already owns the course leaves the gift for someone else" do
    gift = Gift.create!(course: courses(:free), recipient_email: "two@example.com", created_by: users(:owner))
    sign_in_as users(:two) # owns Free Course already
    post redeem_gift_path(gift.token)
    assert_redirected_to gift_claim_path(gift.token)
    assert_match(/still waiting/, flash[:notice])
    assert gift.reload.claimable?
  end

  test "the owner gifts any course by email, even one that isn't sold or published, and the link is claimed" do
    hidden = Course.create!(title: "Hidden Course", slug: "hidden-course", published: false)
    hidden.lessons.create!(position: 1, title: "Hidden one", body: "Secret body")
    sign_in_as users(:owner)
    get admin_gifts_path
    assert_response :success
    assert_select "select[name=course_id] option", text: /Hidden Course \(not published\)/

    post admin_gifts_path, params: { course_id: hidden.id, recipient_email: "one@example.com" }
    assert_redirected_to admin_gifts_path
    assert_match(/We emailed the link/, flash[:notice])
    gift = Gift.last
    assert_equal [ hidden, users(:owner), nil ], [ gift.course, gift.created_by, gift.purchaser ]
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Ironwood Tech gave you Hidden Course", mail.subject
    assert_not users(:one).enrolled_in?(hidden), "nothing is granted until the link is claimed"

    sign_in_as users(:one)
    get learn_lesson_path(hidden, 1)
    assert_redirected_to course_path(hidden)
    post redeem_gift_path(claim_token(mail))
    assert users(:one).enrolled_in?(hidden)
    get learn_lesson_path(hidden, 1)
    assert_response :success
    assert_includes response.body, "Secret body"

    sign_in_as users(:owner)
    post revoke_admin_gift_path(gift)
    assert_not users(:one).enrolled_in?(hidden)
  end

  test "with email off, the owner sees the link once to send by hand, and nothing breaks" do
    sign_in_as users(:owner)
    stub_method(EmailDelivery, :enabled?, -> { false }) do
      post admin_gifts_path, params: { course_id: courses(:cs101).id, recipient_email: "friend@example.com" }
      assert_response :success
      assert_select ".flash", text: /Email isn.t set up yet, so nothing was sent/
      link = css_select("input.copy-field").first["value"]
      assert_match %r{/gift/[A-Za-z0-9_-]+\z}, link
      assert_equal Gift.last, Gift.find_by_token(link.split("/").last)
      assert_nil Gift.last.emailed_at

      # A new link replaces the old one.
      post reissue_admin_gift_path(Gift.last)
      new_link = css_select("input.copy-field").first["value"]
      assert_not_equal link, new_link
      assert_nil Gift.find_by_token(link.split("/").last)
    end
    assert_empty ActionMailer::Base.deliveries

    # The store hides the gift choice when email is off, and the server refuses one.
    with_stripe do
      stub_method(EmailDelivery, :enabled?, -> { false }) do
        get store_course_path(@course)
        assert_select "input[name=gift]", 0
        stub_method(Payments, :create_session, ->(**) { flunk "a gift reached Stripe with email off" }) do
          post store_checkout_path(@course), params: { accept_terms: "1", gift: "1", gift_email: "friend@example.com" }
        end
        assert_match(/Gifts can't be sent just yet/, flash[:alert])
      end
    end
  end

  test "the owner area is for the owner only" do
    sign_in_as users(:one)
    post admin_gifts_path, params: { course_id: courses(:free).id, recipient_email: "me@example.com" }
    assert_redirected_to root_path
    assert_equal 0, Gift.count
  end
end
