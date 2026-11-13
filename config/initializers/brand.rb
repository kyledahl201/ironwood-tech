# Brand settings in one place.
Rails.application.config.x.brand = ActiveSupport::OrderedOptions.new.tap do |b|
  b.name = ENV.fetch("BRAND_NAME", "Ironwood Tech")
  b.full_name = ENV.fetch("BRAND_FULL_NAME", "Ironwood Institute of Technology")
  b.motto = "Ab initio"
  b.contact_email = ENV.fetch("BRAND_CONTACT_EMAIL", "hello@example.com")
  b.host_name = ENV.fetch("BRAND_HOST_NAME", "our hosting provider")
  # Seller identity, shown in the footer and on the terms page. Paid checkout
  # with real money stays off until all three are set (see Payments).
  b.legal_name = ENV["BRAND_LEGAL_NAME"].presence
  b.postal_address = ENV["BRAND_POSTAL_ADDRESS"].presence
  # The honest disclosure, in the footer of every page.
  b.disclosure = "Ironwood is not an accredited school, and it grants no degrees or credit. " \
                 "The faculty and tutors are AI personas, not people. " \
                 "No course promises a job, a raise or any income."
  # The same thing in one line, for the Stripe checkout page.
  b.disclosure_short = "Taught by AI tutors. Not accredited; no degree, credit, job or income promise."
  # Keep the site out of search engines unless the owner opts in.
  b.indexable = ENV["ALLOW_INDEXING"] == "1"
  # ruby.wasm for the code lab: a local copy (bin/build-lab-assets) or the CDN.
  b.ruby_wasm_url = ENV["RUBY_WASM_URL"].presence ||
    (File.exist?(Rails.root.join("public/lab/ruby.wasm")) ? "/lab/ruby.wasm" : "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.10.1/dist/ruby+stdlib.wasm")
end
