class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["MAIL_FROM"].to_s.strip.presence || "Ironwood Tech <hello@ironwoodtech.org>" }
  layout "mailer"
end
