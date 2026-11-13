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
  # The day the terms, refund policy and privacy policy went live, as it should
  # read on the page ("November 24, 2026"). The "Last updated" line shows once set.
  b.policy_date = ENV["POLICY_PUBLISH_DATE"].presence
  # The honest disclosure, in the footer of every page. Legal's wording (v1.1),
  # word for word; the buy box and the Stripe line below say the same thing.
  b.disclosure = "Ironwood Tech's lesson guides and tutors are AI personas, not people. " \
                 "Video lessons are recorded by a real instructor. " \
                 "Ironwood Tech is not an accredited school and grants no degrees or credit."
  # The buy box's own line.
  b.disclosure_buy_box = "Lesson guides are AI personas. Video lessons are recorded by a real instructor."
  # The product description on the Stripe checkout page. PX1's is Legal's line,
  # word for word; any other course gets the same sentence with its own title.
  b.checkout_descriptions = {
    "px1" => "Life and Work, With Claude: AI 101. Self-paced online course by Ironwood Tech (Digital Farm and Garden). Lesson guides are AI personas."
  }.freeze
  b.checkout_description = ->(course) {
    b.checkout_descriptions[course.slug] ||
      "#{course.title}. Self-paced online course by Ironwood Tech (Digital Farm and Garden). Lesson guides are AI personas."
  }
  # Keep the site out of search engines unless the owner opts in.
  b.indexable = ENV["ALLOW_INDEXING"] == "1"
  # ruby.wasm for the code lab: a local copy (bin/build-lab-assets) or the CDN.
  b.ruby_wasm_url = ENV["RUBY_WASM_URL"].presence ||
    (File.exist?(Rails.root.join("public/lab/ruby.wasm")) ? "/lab/ruby.wasm" : "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.10.1/dist/ruby+stdlib.wasm")
end
