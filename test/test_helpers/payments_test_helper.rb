require "openssl"

# Helpers for the selling tests. No test talks to Stripe: the two calls that
# would (creating and reading a Checkout Session) are swapped out, and webhook
# bodies are signed here by hand the way Stripe signs them.
module PaymentsTestHelper
  TEST_KEY = "sk_test_made_up_for_tests".freeze
  WEBHOOK_SECRET = "whsec_made_up_for_tests".freeze

  # Sets environment variables for the block, then puts the old values back.
  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  def with_stripe(extra = {}, &block)
    with_env({ "STRIPE_SECRET_KEY" => TEST_KEY, "STRIPE_WEBHOOK_SECRET" => WEBHOOK_SECRET }.merge(extra), &block)
  end

  def without_stripe(&block)
    with_env({ "STRIPE_SECRET_KEY" => nil, "STRIPE_WEBHOOK_SECRET" => nil }, &block)
  end

  # Replaces a singleton method for the block (tests run in separate processes).
  def stub_method(object, name, callable)
    original = object.method(name)
    object.define_singleton_method(name) { |*args, **kwargs| callable.call(*args, **kwargs) }
    yield
  ensure
    object.define_singleton_method(name, original)
  end

  def as_production(&block)
    stub_method(Rails, :env, -> { ActiveSupport::EnvironmentInquirer.new("production") }, &block)
  end

  def with_seller(legal_name: "Made Up Seller LLC", postal_address: "1 Test Street, Testville", contact_email: "help@seller.test")
    brand = Rails.configuration.x.brand
    old = [ brand.legal_name, brand.postal_address, brand.contact_email ]
    brand.legal_name, brand.postal_address, brand.contact_email = legal_name, postal_address, contact_email
    yield
  ensure
    brand.legal_name, brand.postal_address, brand.contact_email = old
  end

  def checkout_session_data(user:, course:, id: "cs_test_1", payment_status: "paid", payment_intent: "pi_test_1")
    { id: id, object: "checkout.session", payment_status: payment_status, amount_total: course.price_cents, payment_intent: payment_intent,
      metadata: { user_id: user.id.to_s, course_id: course.id.to_s, terms_accepted_at: Time.current.iso8601 } }
  end

  def stripe_event(type, object)
    { id: "evt_test_#{SecureRandom.hex(4)}", object: "event", type: type, data: { object: object } }.to_json
  end

  # "t=<unix time>,v1=<HMAC-SHA256 of 'time.payload'>", as Stripe sends it.
  def stripe_signature(payload, secret: WEBHOOK_SECRET, at: Time.current)
    "t=#{at.to_i},v1=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{at.to_i}.#{payload}")}"
  end

  def post_webhook(payload, signature: stripe_signature(payload))
    headers = { "CONTENT_TYPE" => "application/json" }
    headers["Stripe-Signature"] = signature if signature
    post "/webhooks/stripe", params: payload, headers: headers
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include PaymentsTestHelper }
ActiveSupport.on_load(:active_support_test_case) { include PaymentsTestHelper }
