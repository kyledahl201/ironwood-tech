# Brand and selling settings, kept in one place so the name can change
# after a legal check without touching views. Override with environment
# variables in production.
Rails.application.config.x.brand = ActiveSupport::OrderedOptions.new.tap do |b|
  b.name = ENV.fetch("BRAND_NAME", "Ironwood Tech")
  b.parent = ENV.fetch("BRAND_PARENT", "Digital Farm and Garden")
  b.parent_url = ENV["BRAND_PARENT_URL"].presence
  b.founder = ENV.fetch("BRAND_FOUNDER", "Kyle")
  b.founder_full_name = ENV["BRAND_FOUNDER_FULL_NAME"].presence # copy placeholder [FULL NAME]
  # Seller identity, shown in the footer and terms. Set before taking payments.
  b.legal_name = ENV["BRAND_LEGAL_NAME"].presence # e.g. "Digital Farm and Garden LLC"
  b.postal_address = ENV["BRAND_POSTAL_ADDRESS"].presence
  b.host_name = ENV.fetch("BRAND_HOST_NAME", "our hosting provider")
  b.contact_email = ENV.fetch("BRAND_CONTACT_EMAIL", "hello@example.com")
  b.reply_days = ENV.fetch("BRAND_REPLY_DAYS", "2")
  # Standard disclosure, footer of every page (copy 00-README).
  b.disclosure = "#{b.name} is part of #{b.parent}. Courses are taught by AI tutors and designed by " \
                 "#{b.founder}, the founder. #{b.name} is not an accredited school and does not grant " \
                 "degrees or academic credit."
  b.disclosure_short = "AI-taught course. Not accredited; no degree or credit."
  # Keep the site out of search engines until the owner opts in after a legal check.
  b.indexable = ENV["ALLOW_INDEXING"] == "1"
end
