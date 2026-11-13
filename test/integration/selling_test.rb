require "test_helper"

# Selling a course: the public page, checkout, the Stripe webhook, and who can
# open the PX1 player. Prices, keys and people here are made up.
class SellingTest < ActionDispatch::IntegrationTest
  setup do
    @course = courses(:px1)
    @buyer = users(:customer)
  end

  # --- The public sales page -------------------------------------------------

  test "a signed-out visitor can read a priced course's sales page, with the honest disclosures" do
    get store_path
    assert_response :success
    assert_includes response.body, @course.title

    get store_course_path(@course)
    assert_response :success
    assert_includes response.body, "$29"
    assert_includes response.body, "not an accredited school"
    assert_includes response.body, "AI personas, not people"
    assert_includes response.body, "Video lessons are recorded by a real instructor."
    assert_select "meta[name=robots][content='noindex, nofollow']"
  end

  test "free courses are not in the store, and a sold course is not in the free list" do
    get store_course_path(courses(:free))
    assert_response :not_found

    sign_in_as users(:one)
    get courses_path
    assert_response :success
    assert_select "a[href=?]", course_path(@course), count: 0
    post course_enrollment_path(@course)
    assert_redirected_to store_course_path(@course)
    assert_not users(:one).enrolled_in?(@course)
  end

  test "with no Stripe keys the buy button is disabled with a clear message, never an error" do
    without_stripe do
      get store_course_path(@course)
      assert_response :success
      assert_select "button[disabled]", text: /Buy for \$29/
      assert_includes response.body, "Checkout isn't open yet"
      assert_select "a[href=?]", new_registration_path(course: @course.slug), count: 0
      assert_select "form[action=?]", store_checkout_path(@course), count: 0

      # No account can be made for a course that can't be bought.
      get new_registration_path(course: @course.slug)
      assert_response :forbidden

      # A hand-made request gets a message too, not an error.
      sign_in_as @buyer
      get store_course_path(@course)
      assert_select "button[disabled]", text: /Buy for \$29/
      post store_checkout_path(@course), params: { accept_terms: "1" }
      assert_redirected_to store_course_path(@course)
      assert_match(/isn't open yet/, flash[:alert])
      assert_not @buyer.enrolled_in?(@course)
    end
  end

  test "a sold course with no price can't be bought" do
    with_stripe do
      get store_course_path(courses(:unpriced))
      assert_response :success
      assert_includes response.body, "Not on sale yet"
      get new_registration_path(course: courses(:unpriced).slug)
      assert_response :forbidden
      sign_in_as @buyer
      post store_checkout_path(courses(:unpriced)), params: { accept_terms: "1" }
      assert_match(/isn't on sale yet/, flash[:alert])
    end
  end

  # --- Buying -----------------------------------------------------------------

  test "buy: make an account, tick the terms, go to Stripe Checkout" do
    with_stripe do
      get store_course_path(@course)
      assert_select "a[href=?]", new_registration_path(course: @course.slug), text: /Buy for \$29/
      assert_includes response.body, "Test mode"

      get new_registration_path(course: @course.slug)
      assert_response :success
      assert_difference -> { User.count }, 1 do
        post registration_path(course: @course.slug), params: { user: { name: "New Buyer", email_address: "buyer@example.com", password: "longpassword1", password_confirmation: "longpassword1" } }
      end
      assert_redirected_to store_course_path(@course)
      buyer = User.find_by!(email_address: "buyer@example.com")
      assert buyer.customer_only?
      assert_not buyer.admin?
      assert_not buyer.enrolled_in?(@course), "an account alone is not a purchase"

      # The seller line sits under the price, and the box carries Legal's label.
      get store_course_path(@course)
      assert_select ".buy-box .price + .seller-line", text: "Sold by KD Farm and Garden LLC, doing business as Digital Farm and Garden. Ironwood Tech is a learning brand of Digital Farm and Garden."
      assert_select "form[action=?] label", store_checkout_path(@course), text: "I'm 18 or older and I agree to the Terms of Sale and Privacy Policy." do
        assert_select "input[type=checkbox][name=accept_terms][value='1'][required]"
        assert_select "a[href=?]", terms_path, text: "Terms of Sale"
        assert_select "a[href=?]", privacy_path, text: "Privacy Policy"
      end

      # The box is required on the server too: no tick, or any other value, never reaches Stripe.
      stub_method(Payments, :create_session, ->(**) { flunk "checkout opened without the 18+ and terms box" }) do
        [ {}, { accept_terms: "" }, { accept_terms: "0" }, { accept_terms: "on" } ].each do |params|
          post store_checkout_path(@course), params: params
          assert_redirected_to store_course_path(@course)
          assert_match(/18 or older.*Terms of Sale and Privacy Policy/, flash[:alert])
        end
      end

      asked = nil
      fake = lambda do |**args|
        asked = args
        Struct.new(:url).new("https://checkout.stripe.com/c/pay/cs_test_1")
      end
      stub_method(Payments, :create_session, fake) do
        post store_checkout_path(@course), params: { accept_terms: "1" }
      end
      assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_1"
      assert_equal buyer, asked[:user]
      assert_equal @course, asked[:course]
      assert_includes asked[:success_url], "session_id={CHECKOUT_SESSION_ID}"
      assert_not buyer.enrolled_in?(@course), "going to Stripe is not a purchase"
    end
  end

  test "the policy pages carry Legal's text, with no placeholder banners" do
    { terms_path => [ "Terms of Sale: PX1", "Texas law applies.", "14-day refund, no questions asked." ],
      refunds_path => [ "Refund policy: PX1", "14-day refund, no questions asked." ],
      privacy_path => [ "Privacy policy: Ironwood Tech (covers PX1)", "No tracking pixels.", "<strong>Only in your own browser</strong> on your device.",
                        "Purchase and tax records: 7 years.", "We confirm when it's done.", "Our site loads no ads, trackers or third-party fonts.",
                        "We'll post updates on this page with a new date." ] }.each do |path, lines|
      get path
      assert_response :success, path
      lines.each { |line| assert_includes response.body, line, path }
      assert_not_includes response.body, "LEGAL TO CONFIRM", path
    end
  end

  test "Legal's v1.1 answers are in: the only brackets left are the host and the PO box" do
    get terms_path
    [ "for as long as we offer the course, and at least 12 months.", "A paid Claude plan is needed for some lessons.",
      "Prices don't include sales tax. If tax applies where you live, it's added at checkout.",
      "We may email you about your purchase, such as a receipt or an important change to the course.",
      "within 5 to 10 business days." ].each { |line| assert_includes CGI.unescapeHTML(response.body), line }
    assert_not_includes response.body, "discount"

    get privacy_path
    assert_no_match(/marketing|unsubscribe|course updates|Email tool|90 days|VERIFY/i, response.body)

    visible = ->(body) { Nokogiri::HTML5(body).at_css("main").text.scan(/\[[^\]]*\]/) }
    { terms_path => [], refunds_path => [], privacy_path => [ "[PO Box, Edmond, OK ZIP]", "[host]" ] }.each do |path, brackets|
      get path
      assert_equal brackets, visible.call(response.body), path
      assert_not_includes response.body, "Last updated", "#{path}: no date until go-live"
    end
  end

  test "the policies show the go-live date once POLICY_PUBLISH_DATE is set" do
    brand = Rails.configuration.x.brand
    was = brand.policy_date
    brand.policy_date = "November 24, 2026"
    [ terms_path, refunds_path, privacy_path ].each do |path|
      get path
      assert_includes response.body, "Last updated: November 24, 2026", path
    end
  ensure
    brand.policy_date = was
  end

  test "the footer, the buy box and the Stripe line say the same thing about AI personas" do
    brand = Rails.configuration.x.brand
    footer = "Ironwood Tech's lesson guides and tutors are AI personas, not people. Video lessons are recorded by a real instructor. " \
             "Ironwood Tech is not an accredited school and grants no degrees or credit."
    get store_course_path(@course)
    assert_select "footer #disclosure", text: /\A#{Regexp.escape(footer)}/
    assert_select ".buy-box p", text: "Lesson guides are AI personas. Video lessons are recorded by a real instructor."
    assert_equal "Life and Work, With Claude: AI 101. Self-paced online course by Ironwood Tech (Digital Farm and Garden). Lesson guides are AI personas.",
                 brand.checkout_description.call(@course)
    assert_equal "Free Course. Self-paced online course by Ironwood Tech (Digital Farm and Garden). Lesson guides are AI personas.",
                 brand.checkout_description.call(courses(:free))
  end

  test "an existing account signs in from the sales page and comes back to it" do
    with_stripe do
      get new_session_path(return_to: store_course_path(@course))
      post session_path, params: { email_address: users(:one).email_address, password: "password" }
      assert_redirected_to store_course_path(@course)
    end
    get new_session_path(return_to: "//evil.example/x")
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to portal_url
  end

  test "a Stripe problem at checkout shows a message, not an error" do
    with_stripe do
      sign_in_as @buyer
      stub_method(Payments, :create_session, ->(**) { raise Stripe::APIConnectionError, "down" }) do
        post store_checkout_path(@course), params: { accept_terms: "1" }
      end
      assert_redirected_to store_course_path(@course)
      assert_match(/nothing was charged/, flash[:alert])
    end
  end

  test "the success page enrolls only when Stripe says the session is paid, and only its own buyer" do
    with_stripe do
      sign_in_as @buyer
      unpaid = Stripe::Checkout::Session.construct_from(checkout_session_data(user: @buyer, course: @course, payment_status: "unpaid"))
      stub_method(Payments, :retrieve_session, ->(_id) { unpaid }) do
        get store_checkout_success_path(@course, session_id: "cs_test_1")
      end
      assert_match(/couldn't confirm/, flash[:alert])
      assert_not @buyer.enrolled_in?(@course)

      someone_elses = Stripe::Checkout::Session.construct_from(checkout_session_data(user: users(:one), course: @course))
      stub_method(Payments, :retrieve_session, ->(_id) { someone_elses }) do
        get store_checkout_success_path(@course, session_id: "cs_test_1")
      end
      assert_not @buyer.enrolled_in?(@course)
      assert_not users(:one).enrolled_in?(@course)

      paid = Stripe::Checkout::Session.construct_from(checkout_session_data(user: @buyer, course: @course))
      stub_method(Payments, :retrieve_session, ->(_id) { paid }) do
        get store_checkout_success_path(@course, session_id: "cs_test_1")
      end
      assert_redirected_to store_course_path(@course)
      assert @buyer.enrolled_in?(@course)
    end
  end

  # --- The webhook --------------------------------------------------------------

  test "the webhook needs a valid Stripe signature" do
    payload = stripe_event("checkout.session.completed", checkout_session_data(user: @buyer, course: @course))
    with_stripe do
      post_webhook payload, signature: nil
      assert_response :bad_request
      post_webhook payload, signature: "t=#{Time.current.to_i},v1=#{'0' * 64}"
      assert_response :bad_request
      post_webhook payload, signature: stripe_signature(payload, secret: "whsec_someone_elses")
      assert_response :bad_request
      # A real signature, replayed long after it was made.
      post_webhook payload, signature: stripe_signature(payload, at: 1.hour.ago)
      assert_response :bad_request
      # A real signature for a different body.
      post_webhook payload.sub("pi_test_1", "pi_test_2"), signature: stripe_signature(payload)
      assert_response :bad_request
    end
    # No webhook secret configured: nothing is trusted.
    with_env("STRIPE_SECRET_KEY" => TEST_KEY, "STRIPE_WEBHOOK_SECRET" => nil) do
      post_webhook payload, signature: stripe_signature(payload, secret: "")
      assert_response :bad_request
    end
    assert_not @buyer.enrolled_in?(@course)
  end

  test "a signed checkout.session.completed webhook grants the enrollment, once" do
    payload = stripe_event("checkout.session.completed", checkout_session_data(user: @buyer, course: @course))
    with_stripe do
      assert_difference -> { Enrollment.count }, 1 do
        post_webhook payload
        assert_response :ok
        post_webhook payload
        assert_response :ok
      end
    end
    enrollment = @buyer.enrollments.find_by!(course: @course)
    assert enrollment.active?
    assert_equal "stripe", enrollment.source
    assert_equal 2900, enrollment.amount_cents
    assert_equal "cs_test_1", enrollment.stripe_session_id
    assert_equal "pi_test_1", enrollment.payment_intent_id
    assert enrollment.terms_accepted_at
  end

  test "an unpaid session grants nothing" do
    payload = stripe_event("checkout.session.completed", checkout_session_data(user: @buyer, course: @course, payment_status: "unpaid"))
    with_stripe do
      assert_no_difference -> { Enrollment.count } do
        post_webhook payload
        assert_response :ok
      end
    end
  end

  test "a refund or dispute ends access, a replayed purchase doesn't bring it back, a new purchase does" do
    with_stripe do
      bought = stripe_event("checkout.session.completed", checkout_session_data(user: @buyer, course: @course))
      post_webhook bought
      sign_in_as @buyer
      get course_player_path(@course)
      assert_response :success

      # A partial refund leaves access alone.
      post_webhook stripe_event("charge.refunded", { id: "ch_1", object: "charge", payment_intent: "pi_test_1", refunded: false })
      assert @buyer.enrolled_in?(@course)

      post_webhook stripe_event("charge.refunded", { id: "ch_1", object: "charge", payment_intent: "pi_test_1", refunded: true })
      assert_response :ok
      enrollment = @buyer.enrollments.find_by!(course: @course)
      assert_not enrollment.active?
      assert_equal "refunded", enrollment.revoke_reason
      get course_player_path(@course)
      assert_redirected_to store_course_path(@course)
      get course_downloads_path(@course)
      assert_redirected_to store_course_path(@course)

      post_webhook bought
      assert_not @buyer.enrolled_in?(@course)

      post_webhook stripe_event("checkout.session.completed", checkout_session_data(user: @buyer, course: @course, id: "cs_test_2", payment_intent: "pi_test_2"))
      assert @buyer.enrolled_in?(@course)

      post_webhook stripe_event("charge.dispute.created", { id: "dp_1", object: "dispute", payment_intent: "pi_test_2" })
      assert_equal "disputed", enrollment.reload.revoke_reason
      assert_not @buyer.enrolled_in?(@course)
    end
  end

  # --- The PX1 player -----------------------------------------------------------

  test "the player is not served without an enrollment" do
    get course_player_path(@course)
    assert_redirected_to new_session_path

    [ @buyer, users(:one) ].each do |user|
      sign_in_as user
      get course_player_path(@course)
      assert_redirected_to store_course_path(@course)
      get course_downloads_path(@course)
      assert_redirected_to store_course_path(@course)
      assert_no_match(/Lindgren/, response.body)
    end
  end

  test "the player is never a public file" do
    assert_empty Dir[Rails.public_path.join("**/*")].grep(/px1|course.player/i)
    get "/course_players/px1/index.html"
    assert_response :not_found
  end

  test "the player and its practice files are served with an active enrollment" do
    @buyer.enrollments.create!(course: @course, source: "stripe")
    sign_in_as @buyer
    get course_player_path(@course)
    assert_response :success
    assert_includes response.body, "<title>Life and Work, With Claude</title>"
    assert_includes response.body, "window.COURSE"
    assert_match(/no-store/, response.headers["Cache-Control"])
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    get course_downloads_path(@course)
    assert_response :success
    assert_equal "application/zip", response.media_type
    assert_includes response.body, "ironwood-px1-practice-files/lindgren-home/CLAUDE.md"
    assert_includes response.body, "ironwood-px1-practice-files/reference-hub/index.html"

    get store_course_path(@course)
    assert_select "a[href=?]", course_player_path(@course)
  end

  test "the owner can open the player without buying it" do
    sign_in_as users(:owner)
    get course_player_path(@course)
    assert_response :success
  end

  test "a course with no player has no player page" do
    sign_in_as users(:owner)
    get course_player_path(courses(:free))
    assert_response :not_found
  end

  # --- The owner ----------------------------------------------------------------

  test "the owner sees enrollments, and ending one removes access" do
    enrollment = @buyer.enrollments.create!(course: @course, source: "stripe", amount_cents: 2900)
    sign_in_as users(:one)
    get admin_enrollments_path
    assert_redirected_to root_path
    post revoke_admin_enrollment_path(enrollment)
    assert enrollment.reload.active?

    sign_in_as users(:owner)
    get admin_enrollments_path
    assert_response :success
    assert_includes response.body, @buyer.email_address
    assert_includes response.body, "$29.00"
    get admin_user_path(@buyer)
    assert_response :success

    post revoke_admin_enrollment_path(enrollment)
    assert_not enrollment.reload.active?
    assert_equal "owner", enrollment.revoke_reason

    sign_in_as @buyer
    get course_player_path(@course)
    assert_redirected_to store_course_path(@course)

    sign_in_as users(:owner)
    post reinstate_admin_enrollment_path(enrollment)
    sign_in_as @buyer
    get course_player_path(@course)
    assert_response :success
  end

  test "the owner sets a sold course's price in cents, and a free course has none" do
    sign_in_as users(:owner)
    get edit_admin_course_path(courses(:unpriced))
    assert_select "input[name='course[price_cents]']"
    patch admin_course_path(courses(:unpriced)), params: { course: { price_cents: "1900" } }
    assert_equal 1900, courses(:unpriced).reload.price_cents
    assert_equal "$19", courses(:unpriced).price
    assert courses(:unpriced).on_sale?

    patch admin_course_path(courses(:unpriced)), params: { course: { price_cents: "5" } }
    assert_response :unprocessable_entity
    patch admin_course_path(courses(:unpriced)), params: { course: { price_cents: "" } }
    assert_nil courses(:unpriced).reload.price_cents

    get edit_admin_course_path(courses(:free))
    assert_select "input[name='course[price_cents]']", count: 0
    patch admin_course_path(courses(:free)), params: { course: { price_cents: "1900", paid: "1" } }
    assert_nil courses(:free).reload.price_cents
    assert_not courses(:free).paid?
  end

  test "the owner can look at an unpublished sold course's page; nobody else can" do
    @course.update!(published: false)
    get store_course_path(@course)
    assert_response :not_found
    sign_in_as users(:owner)
    get store_course_path(@course)
    assert_response :success
    assert_includes response.body, "Not published"
  end

  # --- Who sees what --------------------------------------------------------------

  test "an account made by buying a course sees the store and its account, not the portal" do
    sign_in_as @buyer
    %w[/portal /courses /classroom /lab /visualizers /portal/badges /portal/study-log /admin].each do |path|
      get path
      assert_redirected_to store_path, path
    end
    post course_enrollment_path(courses(:free))
    assert_redirected_to store_path
    assert_not @buyer.enrolled_in?(courses(:free))

    [ store_path, portal_account_path, privacy_path, terms_path, refunds_path ].each do |path|
      get path
      assert_response :success, path
    end
    get root_path
    assert_redirected_to store_url

    sign_out
    post session_path, params: { email_address: @buyer.email_address, password: "password" }
    assert_redirected_to store_url
  end

  test "the owner can open the whole portal to a customer account" do
    sign_in_as users(:owner)
    patch admin_user_path(@buyer), params: { user: { customer_only: "0" } }
    assert @buyer.reload.portal_member?
    sign_in_as @buyer
    get portal_path
    assert_response :success
  end

  test "students who were here before keep what they had" do
    assert users(:two).portal_member?
    assert users(:two).enrolled_in?(courses(:free))
    assert enrollments(:two_free).active?
    sign_in_as users(:two)
    get portal_path
    assert_response :success
    get learn_lesson_path(courses(:free), 1)
    assert_response :success
    get courses_path
    assert_response :success
  end

  test "a student who buys a course gets a card for it on Today" do
    users(:two).enrollments.create!(course: @course, source: "stripe")
    sign_in_as users(:two)
    get portal_path
    assert_response :success
    assert_select "a[href=?]", course_player_path(@course)
  end

  test "a revoked enrollment in a free course closes its lessons" do
    enrollments(:two_free).revoke!("owner")
    sign_in_as users(:two)
    get learn_lesson_path(courses(:free), 1)
    assert_redirected_to course_path(courses(:free))
  end
end
