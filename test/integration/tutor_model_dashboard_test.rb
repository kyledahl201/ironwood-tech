require "test_helper"

class TutorModelDashboardTest < ActionDispatch::IntegrationTest
  def with_env(pairs)
    before = pairs.keys.to_h { |k| [ k, ENV[k] ] }
    pairs.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    before.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "the owner sees which model the tutor runs on, and is told when the setting was ignored" do
    sign_in_as users(:owner)
    with_env("ANTHROPIC_API_KEY" => "made-up-key", "TUTOR_MODEL" => nil) do
      get admin_root_path
      assert_response :success
      assert_match "AI tutor: on (claude-sonnet-5-5, up to 40 questions per course a day)", response.body
      assert_no_match(/Check your settings/, response.body)
    end
    with_env("ANTHROPIC_API_KEY" => "made-up-key", "TUTOR_MODEL" => "claude-opus-5.5") do
      get admin_root_path
      assert_select "p[role=status]", text: /TUTOR_MODEL "claude-opus-5.5" isn't on the list \(claude-sonnet-5-5, claude-opus-5-5\), so the tutor uses claude-sonnet-5-5\./
      assert_match "AI tutor: on (claude-sonnet-5-5,", response.body
    end
  end
end
