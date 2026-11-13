# Idempotent: safe to run on every deploy.
require_relative "seeds/agentic_ai_bootcamp"

# Online courses (the AI 360 track).
[ AGENTIC_AI_BOOTCAMP ].each do |data|
  course = Course.find_or_initialize_by(slug: data[:slug])
  course.assign_attributes(data.except(:lessons, :slug).merge(published: course.new_record? ? true : course.published))
  course.save!
  data[:lessons].each.with_index(1) do |l, position|
    course.lessons.find_or_initialize_by(position: position).update!(title: l[:title], body: l[:body])
  end
  course.lessons.where("position > ?", data[:lessons].size).destroy_all
end

# PX1, the first course Ironwood sells. It ships as a finished player
# (db/course_players/px1/), not as lesson rows. The words below are the
# player's own. It is seeded with no price and not published: the owner sets
# the price and publishes it in /admin/courses. Re-running never changes the
# price, the published switch or text the owner has edited.
Course.find_or_create_by!(slug: "px1") do |course|
  course.assign_attributes(
    title: "Life and Work, With Claude",
    paid: true, price_cents: nil, published: false, position: 100,
    level: "AI 101 (PX1). No coding experience needed.",
    hours: "About seven hours, in two sittings",
    tagline: "In one weekend (about seven hours, in two sittings), set up Claude on your Mac, hire a family team of AI helpers, " \
             "plan a real week, and build your own family hub app. No coding experience needed.",
    outcomes: [ "Set up Claude on your Mac", "Hire a family team of AI helpers", "Plan a real week", "Build your own family hub app" ].join("\n"),
    description: <<~MARKDOWN
      **What you need:** a Mac, about seven hours (two sittings work best) and a paid Claude plan. Lessons 3 to 12 use Cowork and the Code tab, which are not on the free plan. The Claude plan is bought from Anthropic, not from Ironwood, and is not part of this course's price. Confirm today's price at claude.com/pricing before you buy.

      This hub lives on your Mac. Getting it onto everyone's phone, each with their own login, is the next course.

      The lessons and cold opens are by AI personas, not real teachers. Your video instructor, [INSTRUCTOR NAME], is a real person.

      The Lindgrens, Cedar Hollow, and every schedule, meal, price and budget in this course are made up. Claude is a trademark of Anthropic. Apple, Mac, iPhone and Apple Calendar are trademarks of Apple Inc. Google, Gmail and Google Calendar are trademarks of Google LLC. This course is not made or endorsed by Anthropic, Apple or Google.
    MARKDOWN
  )
end

# Code-lab exercises written by the faculty (db/seeds/exercises/*.md).
# Re-running updates the text and checks but keeps the owner's open_to_all choice.
Dir[Rails.root.join("db/seeds/exercises/*.md")].sort.each_with_index do |path, i|
  attrs = ExerciseMarkdown.parse(File.read(path))
  exercise = Exercise.find_or_initialize_by(slug: attrs[:slug])
  exercise.assign_attributes(attrs.except(:slug).merge(position: i))
  exercise.save!
end

# Classroom lessons scripted by the faculty (db/seeds/lessons/*.md).
# Re-running updates the script; a student's place in a lesson is kept.
Dir[Rails.root.join("db/seeds/lessons/*.md")].sort.each do |path|
  attrs = ClassLessonMarkdown.parse(File.read(path))
  ClassLesson.find_or_initialize_by(slug: attrs[:slug]).update!(attrs.except(:slug))
end

# Owner account. In production set ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD.
# Made once: when an owner already exists it is left alone, so an owner who has
# changed their email on the Account page doesn't get a second owner account
# (with the password from the settings file) at the next start.
admin_email = ENV.fetch("ADMIN_EMAIL", "owner@example.com")
unless User.admin.exists? || User.exists?(email_address: admin_email)
  password = ENV["ADMIN_PASSWORD"].presence || SecureRandom.base58(16)
  User.create!(name: ENV.fetch("ADMIN_NAME", "Kyle"), email_address: admin_email, password: password, role: :admin)
  puts "Created owner account #{admin_email}#{" with password #{password}" unless ENV['ADMIN_PASSWORD']}"
end
