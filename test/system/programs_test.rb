require "application_system_test_case"

# The Programs page in a real browser: what a visitor, a program's holder and
# a student without it can see and press.
class ProgramsTest < ApplicationSystemTestCase
  setup do
    Program.sync!
    @rails = Program.find_by!(slug: "rails-bootcamp")
    attrs = ClassLessonMarkdown.parse(file_fixture("lesson.md").read)
    @cs101 = ClassLesson.create!(attrs.merge(slug: "zz-s-101", course_code: "CS 101", lesson_number: 1))
    @holder = User.create!(name: "Hal Holder", email_address: "hal@example.com", password: "password12345")
    ProgramEnrollment.grant!(user: @holder, program: @rails, source: "gift")
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password12345"
    click_on "Sign in", match: :first
    assert_no_current_path new_session_path
  end

  test "a visitor sees three tiers, Coming programs with no button, and no price" do
    visit programs_path
    assert_selector "h1", text: "Programs"
    assert_selector "h2", text: "Everyday AI"
    assert_selector "h2", text: "AI at Work"
    assert_selector "h2", text: "Build with AI"
    within "#ai-for-boomers" do
      assert_selector ".pill-coming", text: "COMING"
      assert_no_selector "a.btn"
      assert_no_selector "button"
    end
    within("#life-and-work") { assert_text "Price coming" }
    assert_no_text(/\$\d/)
  end

  test "a program's holder starts a class from the Programs page; someone without it can't" do
    sign_in @holder
    visit programs_path
    within("#rails-bootcamp") do
      assert_selector ".pill-owned", text: "Yours"
      click_on "Start Intro to Programming in Ruby"
    end
    assert_current_path class_lesson_path(@cs101)

    stranger = User.create!(name: "Nora Nobody", email_address: "nora@example.com", password: "password12345")
    click_on "Sign out", match: :first
    sign_in stranger
    visit programs_path
    within("#rails-bootcamp") do
      assert_text "Comes with the program"
      assert_no_link "Start Intro to Programming in Ruby"
    end
    visit class_lesson_path(@cs101)
    assert_text "That class isn't yours yet"
  end
end
