# Whether this server sends email. In production that needs RESEND_API_KEY
# (config/environments/production.rb). When it doesn't, anything that would
# have emailed a link shows it to the owner instead, so nothing is lost.
module EmailDelivery
  module_function

  def enabled? = ActionMailer::Base.perform_deliveries

  # Sends a message now. Returns true when it was handed to the mail server.
  # A failure is logged, never raised: the caller falls back to showing a link.
  def deliver(message)
    return false unless enabled?
    message.deliver_now
    true
  rescue StandardError => e
    Rails.logger.error("[email] #{e.class}: #{e.message}")
    false
  end
end
