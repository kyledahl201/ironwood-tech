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

# Code-lab exercises written by the faculty (db/seeds/exercises/*.md).
# Re-running updates the text and checks but keeps the owner's open_to_all choice.
Dir[Rails.root.join("db/seeds/exercises/*.md")].sort.each_with_index do |path, i|
  attrs = ExerciseMarkdown.parse(File.read(path))
  exercise = Exercise.find_or_initialize_by(slug: attrs[:slug])
  exercise.assign_attributes(attrs.except(:slug).merge(position: i))
  exercise.save!
end

# Owner account. In production set ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD.
admin_email = ENV.fetch("ADMIN_EMAIL", "owner@example.com")
unless User.exists?(email_address: admin_email)
  password = ENV["ADMIN_PASSWORD"].presence || SecureRandom.base58(16)
  User.create!(name: ENV.fetch("ADMIN_NAME", "Kyle"), email_address: admin_email, password: password, role: :admin)
  puts "Created owner account #{admin_email}#{" with password #{password}" unless ENV['ADMIN_PASSWORD']}"
end
