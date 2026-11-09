# Ironwood Tech

The course platform for **Ironwood Tech**, the education arm of Digital Farm and Garden. It sells hands-on courses in AI workflows and agentic AI, taught one step at a time by AI tutor personas, plus an executive consulting inquiry form and a blog with a newsletter sign-up.

Ironwood Tech is not an accredited school and does not grant degrees or academic credit. The tutors are characters played by AI, and the site says so on every page.

## What's in the app

| Area | What it does |
| --- | --- |
| Public site | Home, course catalog, course pages with a published rubric, consulting, blog, about, FAQ, refunds, terms and privacy |
| Accounts | Sign up, log in and password reset (Rails 8 authentication) |
| Checkout | Free courses enroll instantly. Paid courses go through Stripe Checkout, and access is granted only after Stripe confirms payment |
| Learning | Lesson pages with an AI tutor chat that runs on the Claude API, plus Quiz me, Judge it and Hint shortcuts and progress tracking |
| Student portal | Courses, progress, a private record of completion, and a printable certificate of completion |
| Owner area | `/admin`: revenue and lead counts, leads, students, course grants and course pricing |

## Run it locally

You need Ruby 3.3 and SQLite.

```sh
bundle install
bin/rails db:prepare          # creates the database and seeds both courses
bin/dev                       # http://localhost:3000
```

The seed creates an owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, or prints a random password if you don't set one. Everything else is optional, and you can export the variables from `.env.example` in your shell:

- `ANTHROPIC_API_KEY` turns on the tutor. Without it, the tutor saves the question and replies that it's offline.
- `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` turn on paid checkout. Without them, paid courses can't be bought, but you can still grant them from `/admin`.

## Setting prices

The Agentic AI Bootcamp ships with **no price**, so it's listed as "Price coming soon" and can't be bought. Set the price in `/admin/courses`, in cents (for example, 14900 is $149). Re-running the seeds never overwrites a price you set.

## Tests

```sh
bin/rails test
bin/rubocop
bin/brakeman
```

## Deploy (Kamal)

1. Get a small Linux server (any VPS with Docker) and a domain, then point the domain at the server.
2. In `config/deploy.yml`, set the server IP, `proxy.host` to your domain, the registry, `ADMIN_EMAIL` and `BRAND_CONTACT_EMAIL`.
3. Export the secrets listed in `.kamal/secrets` in your shell. Generate `SECRET_KEY_BASE` with `bin/rails secret`.
4. Run `bin/kamal setup` the first time, then `bin/kamal deploy` after that.
5. In Stripe, add a webhook to `https://YOUR-DOMAIN/webhooks/stripe` for `checkout.session.completed`.

SQLite lives in the `storage` volume, so back it up (Litestream or a nightly copy) before you take real payments.

## Before you take real money

- [ ] Get a legal check on the name, the refund policy, terms and privacy policy, and selling where you sell
- [ ] Replace the placeholder privacy and terms pages with real policies
- [ ] Set the support email, your full name and the Digital Farm and Garden link
- [ ] Set course prices and confirm the AI Workflow Fundamentals module list
- [ ] Use Stripe live keys after a test purchase and a test refund
- [ ] Turn on search indexing (`ALLOW_INDEXING=1`), which also removes the pre-launch strip
