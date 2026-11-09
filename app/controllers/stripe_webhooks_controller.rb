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
