require "test_helper"

# When checkout is open, and when it is held shut.
class PaymentsTest < ActiveSupport::TestCase
  LIVE_KEY = "sk_live_made_up_for_tests".freeze

  test "off without a key" do
    without_stripe do
      assert_equal :no_key, Payments.blocked_reason
      assert_not Payments.enabled?
      assert_match(/STRIPE_SECRET_KEY/, Payments.status_line)
    end
  end

  test "a test key works in development and test with no seller details" do
    with_stripe do
      assert_nil Payments.blocked_reason
      assert Payments.test_mode?
      assert_match(/TEST mode/, Payments.status_line)
    end
  end

  test "production guard: no paid checkout until the seller's name, address and a real email are set" do
    as_production do
      with_env("STRIPE_SECRET_KEY" => LIVE_KEY) do
        assert_equal :seller_identity, Payments.blocked_reason
        with_seller(postal_address: nil) { assert_equal :seller_identity, Payments.blocked_reason }
        with_seller(legal_name: nil) { assert_equal :seller_identity, Payments.blocked_reason }
        with_seller(contact_email: "hello@example.com") { assert_equal :seller_identity, Payments.blocked_reason }
        with_seller do
          assert_nil Payments.blocked_reason
          assert_match(/LIVE mode/, Payments.status_line)
        end
      end
    end
  end

  test "a live key needs the seller's details everywhere, not only in production" do
    with_env("STRIPE_SECRET_KEY" => LIVE_KEY) do
      assert_equal :seller_identity, Payments.blocked_reason
      with_seller { assert_nil Payments.blocked_reason }
    end
  end

  test "a test key in production needs the seller's details and an explicit opt-in" do
    as_production do
      with_stripe("STRIPE_TEST_IN_PRODUCTION" => nil) do
        assert_equal :seller_identity, Payments.blocked_reason
        with_seller { assert_equal :test_key_in_production, Payments.blocked_reason }
      end
      with_stripe("STRIPE_TEST_IN_PRODUCTION" => "1") do
        with_seller { assert_nil Payments.blocked_reason }
      end
    end
  end

  test "the sales page keeps the buy button off in production without seller details" do
    session = ActionDispatch::Integration::Session.new(Rails.application)
    as_production do
      with_env("STRIPE_SECRET_KEY" => LIVE_KEY) do
        session.get "/store/px1"
        assert_equal 200, session.response.status
        assert_includes session.response.body, "Checkout isn't open yet"
        assert_no_match(/join\?course=px1/, session.response.body)
      end
    end
  end

  test "price formatting and what counts as on sale" do
    assert_equal "$29", courses(:px1).price
    assert_equal "$19.50", Course.new(price_cents: 1950).price
    assert courses(:px1).on_sale?
    assert_not courses(:unpriced).on_sale?
    assert_not courses(:free).on_sale?
    assert_not Course.new(title: "x", slug: "x", price_cents: 10).valid?
  end

  test "the seeded PX1 course has no price" do
    seeds = Rails.root.join("db/seeds.rb").read
    assert_match(/slug: "px1"/, seeds)
    assert_match(/price_cents: nil/, seeds)
  end

  test "no secret is written in the repository's settings example" do
    Rails.root.join(".env.example").read.each_line do |line|
      next unless line.match?(/\A(STRIPE_|BRAND_LEGAL|BRAND_POSTAL)/)
      assert_match(/\A[A-Z_]+=\s*(#.*)?\z/, line.chomp, "#{line.split('=').first} must be empty in .env.example")
    end
  end
end
