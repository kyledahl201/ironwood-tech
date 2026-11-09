# Idempotent: safe to run on every deploy. Content lives in db/seeds/*.rb.
require_relative "seeds/ai_workflow_fundamentals"
require_relative "seeds/agentic_ai_bootcamp"

def upsert_course(data)
  course = Course.find_or_initialize_by(slug: data[:slug])
  attrs = data.except(:lessons, :slug)
  attrs = attrs.except(:price_cents) if course.persisted? # never overwrite a price the owner set
  course.assign_attributes(attrs.merge(published: course.new_record? ? true : course.published))
  course.save!
  data[:lessons].each.with_index(1) do |l, position|
    lesson = course.lessons.find_or_initialize_by(position: position)
    lesson.update!(title: l[:title], body: l[:body])
  end
  course.lessons.where("position > ?", data[:lessons].size).destroy_all
  course
end

[ AI_WORKFLOW_FUNDAMENTALS, AGENTIC_AI_BOOTCAMP ].each { |c| upsert_course(c) }

# Owner account. In production set ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD.
admin_email = ENV.fetch("ADMIN_EMAIL", "owner@example.com")
unless User.exists?(email_address: admin_email)
  password = ENV["ADMIN_PASSWORD"].presence || SecureRandom.base58(16)
  User.create!(name: ENV.fetch("ADMIN_NAME", "Kyle"), email_address: admin_email, password: password, role: :admin)
  puts "Created owner account #{admin_email}#{" with password #{password}" unless ENV['ADMIN_PASSWORD']}"
end

Post.find_or_create_by!(slug: "why-ironwood-tech") do |p|
  b = Rails.configuration.x.brand
  p.title = "Why I'm starting #{b.name} as its first student"
  p.summary = "A bootcamp years ago didn't stick. This time I'm starting from the beginning, with AI tutors and honest feedback."
  p.published_at = Time.current
  p.body = <<~MD
    Years ago I did a coding bootcamp, and very little of it stuck. I could follow along, but I couldn't build anything on my own afterwards.

    So I started over, from the beginning. I built myself a school: a tutor for each subject, one step at a time, real projects, and feedback that tells me plainly when my work isn't there yet. The tutors are AI personas, and I'll always say so.

    #{b.name} is the part of that school I think will help other people most: practical AI workflows for professionals, and an Agentic AI Bootcamp for people who want to build agents they can test and trust.

    A few promises:

    - **No credential theater.** #{b.name} isn't accredited and doesn't grant degrees or credit. You get skills, a portfolio, and a certificate that says what you completed.
    - **No outcome promises.** I won't tell you this will get you a job or a raise. I'll tell you exactly what the work is.
    - **I'm doing it too.** I'm student number one, and I'll write here about what I learn and what I get wrong.

    If that sounds useful, start with AI Workflow Fundamentals. It's free.
  MD
end
