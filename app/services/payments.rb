# A thin wrapper around Stripe Checkout. Keys come only from the environment
# (.env.example lists them); nothing here is ever stored in the repository.
#
# Checkout is off until STRIPE_SECRET_KEY is set, so the portal runs without a
# Stripe account. An enrollment is created only after Stripe confirms payment:
# from the signed webhook, or when the buyer lands back on the success page and
# the session is read back from Stripe. Never from the browser's word alone.
module Payments
  class InvalidSignature < StandardError; end

  # How old a webhook's signature may be before it's refused (replay guard).
  WEBHOOK_TOLERANCE = 300

  module_function

  def secret_key = ENV["STRIPE_SECRET_KEY"].to_s.strip.presence
  def webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].to_s.strip.presence

  def test_mode? = secret_key.to_s.match?(/\A(sk|rk)_test_/)
  def live_mode? = secret_key.present? && !test_mode?

  # Why checkout is closed, or nil when it's open.
  #   :no_key           no STRIPE_SECRET_KEY
  #   :seller_identity  real money (a live key, or any key in production) needs
  #                     the seller's legal name, postal address and contact email
  #   :test_key_in_production  a test key on the real site would hand out courses
  #                     for a test card number, so it needs an explicit opt-in
  def blocked_reason
    return :no_key unless secret_key
    return :seller_identity if (live_mode? || Rails.env.production?) && !seller_identity_complete?
    return :test_key_in_production if test_mode? && Rails.env.production? && ENV["STRIPE_TEST_IN_PRODUCTION"] != "1"
    nil
  end

  def enabled? = blocked_reason.nil?

  # Consumer law expects the seller's name, address and contact on the site.
  def seller_identity_complete?
    b = Rails.configuration.x.brand
    b.legal_name.present? && b.postal_address.present? && b.contact_email.present? && !b.contact_email.to_s.strip.downcase.end_with?("example.com")
  end

  # One line for the owner's dashboard.
  def status_line
    case blocked_reason
    when :no_key then "off (set STRIPE_SECRET_KEY)"
    when :seller_identity then "blocked (set BRAND_LEGAL_NAME, BRAND_POSTAL_ADDRESS and a real BRAND_CONTACT_EMAIL)"
    when :test_key_in_production then "blocked (a test key in production needs STRIPE_TEST_IN_PRODUCTION=1)"
    else "#{test_mode? ? 'on, TEST mode (no real charges)' : 'on, LIVE mode'}; webhook secret #{webhook_secret ? 'set' : 'NOT set, so refunds will not end access'}"
    end
  end

  def client = Stripe::StripeClient.new(secret_key)

  # Sales tax is a business decision: set STRIPE_TAX=1 only after turning on
  # Stripe Tax in the Stripe dashboard.
  def tax_enabled? = ENV["STRIPE_TAX"] == "1"

  # Sells a course, or a whole program (program:). gift_to: the recipient's
  # email when it's bought as a gift. The buyer then gets no access; the
  # recipient gets a claim link (Gift).
  def create_session(user:, success_url:, cancel_url:, terms_accepted_at:, course: nil, program: nil, gift_to: nil)
    product = program || course
    metadata = { user_id: user.id, terms_accepted_at: terms_accepted_at.iso8601 }
    program ? metadata[:program_id] = program.id : metadata[:course_id] = course.id
    metadata[:gift_recipient] = gift_to if gift_to.present?
    client.v1.checkout.sessions.create(
      mode: "payment",
      customer_email: user.email_address,
      client_reference_id: user.id.to_s,
      metadata: metadata,
      # The charge carries our ids, and Stripe emails a receipt in live mode.
      payment_intent_data: { receipt_email: user.email_address, metadata: metadata },
      automatic_tax: { enabled: tax_enabled? },
      billing_address_collection: tax_enabled? ? "required" : "auto",
      line_items: [ {
        quantity: 1,
        price_data: {
          currency: "usd",
          unit_amount: product.price_cents,
          product_data: { name: gift_to.present? ? "#{product.title} (gift)" : product.title, description: Rails.configuration.x.brand.checkout_description.call(product) }
        }
      } ],
      success_url: success_url,
      cancel_url: cancel_url
    )
  end

  def retrieve_session(session_id) = client.v1.checkout.sessions.retrieve(session_id)

  # The success page: read the session back from Stripe, then enroll (or, for
  # a gift, make the Gift). Returns the Enrollment or the Gift.
  def fulfill(session_id, expected_user: nil)
    return nil if session_id.blank? || !enabled?
    grant(retrieve_session(session_id), expected_user: expected_user)
  rescue Stripe::StripeError => e
    Rails.logger.error("[payments] #{e.class}: #{e.message}")
    nil
  end

  # Creates the enrollment for a paid Checkout Session (one read back from
  # Stripe, or one inside a signature-checked webhook). Safe to call twice:
  # the success page and the webhook both do. Returns nil if it isn't paid.
  def grant(session, expected_user: nil)
    return nil unless session.payment_status == "paid"
    metadata = session.metadata
    user = User.find_by(id: metadata && metadata["user_id"])
    return nil unless user
    return nil if expected_user && expected_user != user
    return grant_program(session, user) if metadata["program_id"].present?
    course = Course.find_by(id: metadata["course_id"])
    return nil unless course
    return grant_gift(session, user, course) if metadata["gift_recipient"].present?

    paid = { source: "purchase", amount_cents: session.amount_total, stripe_session_id: session.id,
             payment_intent_id: session.payment_intent.to_s.presence,
             terms_accepted_at: metadata["terms_accepted_at"].presence, gift: nil }
    enrollment = begin
      Enrollment.find_or_create_by!(user: user, course: course) { |e| e.assign_attributes(paid) }
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # The success page and the webhook arrived together; the other one made it.
      Enrollment.find_by!(user: user, course: course)
    end
    if enrollment.stripe_session_id != session.id
      # A new purchase after a refund restores access; a free or owner-granted
      # enrollment that is still active just gets the payment recorded on it.
      # A replayed event for a refunded payment changes nothing.
      enrollment.reinstate!(**paid) if !enrollment.active? || !enrollment.paid?
    end
    enrollment
  end

  # A paid program: the buyer holds the program, and so every class in it. Or,
  # bought as a gift, the recipient gets a claim link. Safe to call twice.
  def grant_program(session, user)
    program = Program.find_by(id: session.metadata["program_id"])
    return nil unless program
    return grant_gift(session, user, program) if session.metadata["gift_recipient"].present?
    existing = ProgramEnrollment.find_by(stripe_session_id: session.id)
    return existing if existing # a replay, or the other caller; a refunded payment stays refunded
    ProgramEnrollment.grant!(user: user, program: program, source: "purchase", amount_cents: session.amount_total,
                             stripe_session_id: session.id, payment_intent_id: session.payment_intent.to_s.presence,
                             terms_accepted_at: session.metadata["terms_accepted_at"].presence, gift: nil)
  rescue ActiveRecord::RecordNotUnique
    ProgramEnrollment.find_by!(user: user, program: program)
  end

  # A paid gift: the Gift is made once (the success page and the webhook both
  # call this), and the recipient is emailed the claim link the first time.
  # The buyer is not enrolled.
  def grant_gift(session, buyer, product)
    gift = Gift.find_by(stripe_session_id: session.id)
    return gift if gift
    gift = Gift.create!((product.is_a?(Program) ? :program : :course) => product, purchaser: buyer, recipient_email: session.metadata["gift_recipient"].to_s,
                        amount_cents: session.amount_total, stripe_session_id: session.id,
                        payment_intent_id: session.payment_intent.to_s.presence,
                        terms_accepted_at: session.metadata["terms_accepted_at"].presence)
    gift.update!(emailed_at: Time.current) if EmailDelivery.deliver(GiftMailer.claim(gift, gift.token))
    gift
  rescue ActiveRecord::RecordNotUnique
    Gift.find_by!(stripe_session_id: session.id) # the other caller made it
  end

  # Full refunds and disputes end access to the course (or the program), and end a gift (and
  # the access it gave, if it was claimed).
  def handle_event(event)
    object = event.data.object
    case event.type
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      grant(object)
    when "charge.refunded"
      revoke(object.payment_intent, "refunded") if object.refunded
    when "charge.dispute.created"
      revoke(object.payment_intent, "disputed")
    end
  end

  # A program the student still holds keeps its classes open: a course they
  # also bought on its own, now refunded, comes back through the program.
  def revoke(payment_intent_id, reason)
    return if payment_intent_id.blank?
    users = Set.new
    Enrollment.where(payment_intent_id: payment_intent_id.to_s).includes(:program_enrollment).find_each do |e|
      next if e.program_enrollment&.active? # held by a program now, not by this payment
      e.revoke!(reason)
      users << e.user
    end
    ProgramEnrollment.where(payment_intent_id: payment_intent_id.to_s).find_each { |pe| pe.revoke!(reason) }
    Gift.where(payment_intent_id: payment_intent_id.to_s).find_each { |g| g.revoke!(reason) }
    users.each { |user| user.program_enrollments.active.each { |pe| pe.fan_out!(reinstate: true) } }
  end

  # Raises InvalidSignature unless the payload was signed with our webhook
  # secret (HMAC-SHA256 over "timestamp.payload") within the tolerance.
  def construct_event(payload, signature)
    raise InvalidSignature if webhook_secret.nil? || signature.blank?
    Stripe::Webhook.construct_event(payload, signature, webhook_secret, tolerance: WEBHOOK_TOLERANCE)
  rescue Stripe::SignatureVerificationError, JSON::ParserError
    raise InvalidSignature
  end
end
