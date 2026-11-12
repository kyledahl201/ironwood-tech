require "test_helper"

class TutorModelTest < ActiveSupport::TestCase
  def with_model(value)
    before = ENV["TUTOR_MODEL"]
    value.nil? ? ENV.delete("TUTOR_MODEL") : ENV["TUTOR_MODEL"] = value
    yield
  ensure
    before.nil? ? ENV.delete("TUTOR_MODEL") : ENV["TUTOR_MODEL"] = before
  end

  test "the tutor runs on the cheaper model unless told otherwise" do
    with_model(nil) { assert_equal "claude-sonnet-5-5", Tutor.model }
    with_model("") { assert_equal "claude-sonnet-5-5", Tutor.model }
  end

  test "the setting can pick any model on the list, spaces forgiven" do
    with_model("claude-opus-5-5") { assert_equal "claude-opus-5-5", Tutor.model }
    with_model(" claude-opus-5-5 ") { assert_equal "claude-opus-5-5", Tutor.model }
  end

  test "a typo or a model that isn't on the list falls back to the default" do
    with_model("claude-opus") { assert_equal Tutor::DEFAULT_MODEL, Tutor.model }
    with_model("some-other-model") { assert_equal Tutor::DEFAULT_MODEL, Tutor.model }
  end

  test "the request the tutor sends names the chosen model" do
    sent = nil
    reply = Struct.new(:stop_reason, :content).new(:end_turn, [ Struct.new(:type, :text).new(:text, "Made-up answer") ])
    messages = Object.new
    messages.define_singleton_method(:create) { |**args| sent = args; reply }
    client = Struct.new(:messages).new(messages)
    lesson = ClassLesson.create!(slug: "zz-model", course_code: "ZZ 100", lesson_number: 1, title: "Made up", steps: [ { "kind" => "teach", "text" => "Hello" } ])
    tutor = Tutor.new(user: users(:one), class_lesson: lesson)
    tutor.instance_variable_set(:@client, client)
    before = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "made-up-key"
    with_model(nil) { assert_equal "Made-up answer", tutor.reply }
    assert_equal "claude-sonnet-5-5", sent[:model]
    with_model("claude-opus-5-5") { tutor.reply }
    assert_equal "claude-opus-5-5", sent[:model]
  ensure
    ENV["ANTHROPIC_API_KEY"] = before
  end
end
