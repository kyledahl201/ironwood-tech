# Thin wrapper around Stripe Checkout. Payments are off until STRIPE_SECRET_KEY
# is set, so the site runs (free courses, admin grants) without a Stripe account.
module Payments
  class InvalidSignature < StandardError; end

  module_function

  def enabled?
    ENV["STRIPE_SECRET_KEY"].present?
  end

  def client
    Stripe::StripeClient.new(ENV.fetch("STRIPE_SECRET_KEY"))
  end

  # Sales tax is a business decision: set STRIPE_TAX=1 only after turning on
  # Stripe Tax (or getting an accountant's answer that you don't need it).
  def tax_enabled? = ENV["STRIPE_TAX"] == "1"

  def checkout_session(course:, user:, success_url:, cancel_url:, terms_accepted_at:)
    metadata = { user_id: user.id, course_id: course.id, terms_accepted_at: terms_accepted_at.iso8601 }
    client.v1.checkout.sessions.create(
      mode: "payment",
      customer_email: user.email_address,
      client_reference_id: user.id.to_s,
      metadata: metadata,
      # Stripe emails a receipt (live mode) and the charge carries our ids.
      payment_intent_data: { receipt_email: user.email_address, metadata: metadata },
      automatic_tax: { enabled: tax_enabled? },
      billing_address_collection: tax_enabled? ? "required" : "auto",
      line_items: [ {
        quantity: 1,
        price_data: {
          currency: "usd",
          unit_amount: course.price_cents,
          product_data: { name: course.title, description: Rails.configuration.x.brand.disclosure_short }
        }
      } ],
      success_url: success_url,
      cancel_url: cancel_url
    )
  end

  # Creates the enrollment for a paid Checkout Session. Safe to call twice
  # (success redirect and webhook both call it). Returns nil if unpaid.
  def fulfill(session_id, expected_user: nil)
    return nil if session_id.blank? || !enabled?
    session = client.v1.checkout.sessions.retrieve(session_id)
    return nil unless session.payment_status == "paid"

    user = User.find_by(id: session.metadata["user_id"])
    course = Course.find_by(id: session.metadata["course_id"])
    return nil unless user && course
    return nil if expected_user && expected_user != user

    paid = { source: "stripe", amount_cents: session.amount_total, stripe_session_id: session.id,
             payment_intent_id: session.payment_intent.to_s.presence,
             terms_accepted_at: session.metadata["terms_accepted_at"].presence }
    enrollment = Enrollment.find_or_create_by!(user: user, course: course) { |e| e.assign_attributes(paid) }
    # A new purchase after a refund restores access; a replayed event for the
    # refunded payment does not.
    enrollment.reinstate!(**paid) if !enrollment.active? && enrollment.stripe_session_id != session.id
    enrollment
  rescue Stripe::StripeError => e
    Rails.logger.error("[payments] #{e.class}: #{e.message}")
    nil
  end

  # Full refunds and disputes end access to the course.
  def handle_event(event)
    object = event.data.object
    case event.type
    when "checkout.session.completed"
      fulfill(object.id)
    when "charge.refunded"
      revoke(object.payment_intent, "refunded") if object.refunded
    when "charge.dispute.created"
      revoke(object.payment_intent, "disputed")
    end
  end

  def revoke(payment_intent_id, reason)
    return if payment_intent_id.blank?
    Enrollment.where(payment_intent_id: payment_intent_id.to_s).find_each { |e| e.revoke!(reason) }
  end

  def construct_event(payload, signature)
    Stripe::Webhook.construct_event(payload, signature, ENV.fetch("STRIPE_WEBHOOK_SECRET"))
  rescue Stripe::SignatureVerificationError, JSON::ParserError, KeyError
    raise InvalidSignature
  end
end
