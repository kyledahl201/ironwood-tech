require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # FORCE_SSL=1 is for a host that ends HTTPS in front of the app (Fly.io, see fly.toml):
  # treat every request as HTTPS, send Strict-Transport-Security and mark cookies secure.
  # Leave it unset where the site is opened over plain http (the Mac install on
  # localhost:3000), or signing in would stop working there.
  if ENV["FORCE_SSL"] == "1"
    config.assume_ssl = true
    config.force_ssl = true

    # The host's health check calls /up over plain http from inside its network.
    config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  # APP_HOST is the public address, for example ironwoodtech.org.
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com"), protocol: ENV["FORCE_SSL"] == "1" ? "https" : "http" }

  # Email goes out through Resend's SMTP server (docs/DEPLOY-FLY.md, "Turn on
  # email"). The key comes only from the environment. With no key, nothing is
  # sent and nothing breaks: the owner area shows gift links to send by hand
  # (EmailDelivery.enabled?).
  if ENV["RESEND_API_KEY"].to_s.strip.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: "smtp.resend.com",
      port: 587,
      user_name: "resend",
      password: ENV["RESEND_API_KEY"].to_s.strip,
      authentication: :plain,
      enable_starttls_auto: true
    }
  else
    config.action_mailer.perform_deliveries = false
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
