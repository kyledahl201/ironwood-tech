# Stripe calls this when a payment completes, is refunded or is disputed.
# There is no sign-in here: the request is trusted only if its signature was
# made with STRIPE_WEBHOOK_SECRET. Anything else gets a 400 and changes nothing.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    event = Payments.construct_event(request.body.read, request.headers["Stripe-Signature"])
    Payments.handle_event(event)
    head :ok
  rescue Payments::InvalidSignature
    head :bad_request
  end
end
