# Brand settings in one place.
Rails.application.config.x.brand = ActiveSupport::OrderedOptions.new.tap do |b|
  b.name = ENV.fetch("BRAND_NAME", "Ironwood Tech")
  b.full_name = ENV.fetch("BRAND_FULL_NAME", "Ironwood Institute of Technology")
  b.motto = "Ab initio"
  b.contact_email = ENV.fetch("BRAND_CONTACT_EMAIL", "hello@example.com")
  b.host_name = ENV.fetch("BRAND_HOST_NAME", "our hosting provider")
  # Office of Communications, copy/portal/01-public-page.md
  b.disclosure = "Ironwood is a non-profit personal curriculum. It is not an accredited school, it sells nothing, " \
                 "and it grants no degrees or credit. The faculty are AI personas."
  # Personal site: keep it out of search engines unless the owner opts in.
  b.indexable = ENV["ALLOW_INDEXING"] == "1"
  # ruby.wasm for the code lab: a local copy (bin/build-lab-assets) or the CDN.
  b.ruby_wasm_url = ENV["RUBY_WASM_URL"].presence ||
    (File.exist?(Rails.root.join("public/lab/ruby.wasm")) ? "/lab/ruby.wasm" : "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.10.1/dist/ruby+stdlib.wasm")
end
