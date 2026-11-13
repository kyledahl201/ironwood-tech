require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  setup do
    Program.sync!
    @rails = Program.find_by!(slug: "rails-bootcamp")
    @student = User.create!(name: "Pat Program", email_address: "pat@example.com", password: "password12345") # owns nothing yet
  end

  test "sync makes the three tiers' programs and puts each course in its program" do
    assert_equal %w[PX1 PYX PX2], Program.tiers.map(&:code)
    assert_equal [ "Everyday AI", "AI at Work", "Build with AI" ], Program.tiers.map(&:name)
    assert_equal [ [ "PX1", "Life and Work, With Claude: AI 101" ], [ "PX1", "AI for Boomers" ], [ "PYX", "AI for Boomers 2: Electric Boogaloo" ],
                   [ "PYX", "AI for Contractors" ], [ "PYX", "AI for Sales" ], [ "PX2", "14-Week Agentic AI" ], [ "PX2", "Engineering / Rails Bootcamp" ] ],
                 Program.ordered.map { |p| [ p.tier, p.title ] }
    assert_equal courses(:px1).reload.program, Program.find_by!(slug: "life-and-work")
    assert_equal [ courses(:cs090), courses(:cs101) ], @rails.courses.to_a
    assert_equal Program.find_by!(slug: "agentic-ai"), courses(:ai360).reload.program
    assert_nil courses(:tour).reload.program # Start here stays on its own
    assert_equal "Build with AI", @rails.tier_name
    assert Program.find_by!(slug: "ai-for-boomers").coming?
    assert_not @rails.coming?
    assert Program.where.not(price_cents: nil).none?, "no price is made up"
  end

  test "sync is safe to run again and keeps the owner's edits and moves" do
    @rails.update!(title: "Owner's title", price_cents: 9900)
    courses(:cs090).update!(program: Program.find_by!(slug: "agentic-ai"))
    assert_no_difference -> { Program.count } do
      Program.sync!
    end
    assert_equal [ "Owner's title", 9900 ], [ @rails.reload.title, @rails.price_cents ]
    assert_equal "agentic-ai", courses(:cs090).reload.program.slug
  end

  test "a program with no classes is Coming and can never be on sale" do
    boomers = Program.find_by!(slug: "ai-for-boomers")
    boomers.update!(price_cents: 1900)
    assert boomers.coming?
    assert_not boomers.on_sale?
    @rails.update!(price_cents: 1900)
    assert @rails.on_sale?
    assert_equal "$19", @rails.price
    @rails.update!(published: false)
    assert_not @rails.on_sale?
  end

  test "holding a program gives an enrollment in every class in it, so every class opens" do
    assert_not @student.can_open?(courses(:cs090))
    pe = ProgramEnrollment.grant!(user: @student, program: @rails, source: "admin")
    assert pe.active?
    assert @student.can_open?(courses(:cs090))
    assert @student.can_open?(courses(:cs101))
    assert @student.can_open_code?("CS 101")
    assert_not @student.can_open?(courses(:ai360)), "another program's class stays closed"
    assert @rails.owned_by?(@student)
    assert_equal [ pe, pe ], @student.enrollments.where(course: @rails.courses).map(&:program_enrollment)
  end

  test "ending a program ends the classes it gave, but not a class the student owns on its own" do
    own = @student.enrollments.create!(course: courses(:cs101), source: "purchase")
    pe = ProgramEnrollment.grant!(user: @student, program: @rails, source: "gift")
    assert_nil own.reload.program_enrollment, "the class they bought stays theirs, not the program's"
    pe.revoke!("owner")
    assert_not @student.reload.can_open?(courses(:cs090))
    assert @student.can_open?(courses(:cs101))
    assert_not @rails.owned_by?(@student)

    pe.reinstate!
    assert @student.reload.can_open?(courses(:cs090))
  end

  test "a class placed in a program later goes to everyone who holds it" do
    ProgramEnrollment.grant!(user: @student, program: @rails, source: "admin")
    newer = Course.create!(title: "Rails 1", slug: "rails-1", code: "RB 101", published: true)
    newer.update!(program: @rails)
    assert_not @student.can_open?(newer)
    Program.sync!
    assert @student.reload.can_open?(newer)
  end

  test "a program's owner view: the site's owner, the holder, or someone who owns every class already" do
    assert @rails.owned_by?(users(:owner))
    assert_not @rails.owned_by?(nil)
    @rails.courses.each { |c| @student.enrollments.create!(course: c, source: "admin") }
    assert @rails.owned_by?(@student)
    assert_not @student.holds_program?(@rails)
    assert_not Program.find_by!(slug: "ai-for-boomers").owned_by?(@student)
  end
end
