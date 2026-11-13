# Ironwood Tech

The learning portal for **Ironwood Tech**. It began as one student's personal university and still is that: the owner studies here, and friends join free by invitation. It also sells courses, starting with PX1, through Stripe Checkout.

Ironwood Tech is not an accredited school and grants no degrees or credit. Its lesson guides and tutors are AI personas, not people; video lessons are recorded by a real instructor. The site says so on every page.

## What's in the app

| Area | What it does |
| --- | --- |
| Public pages | One page about the school, the store, plus terms, refunds and privacy. Search engines are told not to index any of it unless `ALLOW_INDEXING=1` |
| Accounts | Sign-up by invite link (the whole portal, free) or while buying a course (the store and what was bought only), sign in and password reset (Rails 8 authentication) |
| Store | `/store`: a public sales page for each sold course, Stripe Checkout, and a signed webhook that grants or ends access. See "Selling courses" below |
| Today | The dashboard: today's class or lesson, the next gate countdown, the crest tree that lights up with progress, a 26-week study heatmap and a forgiving streak |
| Classroom | Lessons scripted by the faculty and played step by step: the professor's board on top, a workbench underneath with a practice Terminal (a pretend computer in the browser), a console and an editor for Ruby, and a console and an editor for Python. Tasks are checked as you type, hints come one at a time, "on your Mac" steps check pasted output, and quiz answers are checked on the server. Finishing a lesson counts as taught. Each lesson also has a study page (study guide, flashcards, the questions from class again) and homework that plays in the same workbench; handed-in homework waits for the professor, who grades it. "Copy for my tutor" copies the task, the student's work and the checks to paste into a chat with their professor. A course can ship a tutor kit (`db/tutor_kits/<course>/*.md`): Markdown files, with no answers, that a student downloads and adds to their own Claude project so the course's professor can coach them there. The Classroom tab opens the class the student is in (`ClassLesson.current_for`); a student who hasn't begun gets a welcome with one class to start and the full course list. In class, **Switch class** draws that list over the page and **Ask Prof. …** opens a chat with the AI tutor beside the lesson: it is sent the lesson so far (never later steps or quiz answers) and, unless the student unticks the box, their workbench |
| Courses | One list of every course, grouped by program (the department it belongs to; `Catalog`, `config/course_catalog.yml`): a classroom course, a reading course, or both as one row. Details open in place, and one button goes into the course |
| Code lab | Ruby exercises written by the faculty, with a real editor (CodeMirror), Ruby running in the browser (ruby.wasm), automatic checks, a line-by-line output diff and hints one at a time. Exercises open after their lesson is taught. No solutions are stored |
| Visualizers | Step-through tools in one frame: a loop tracer, a hash lookup and a method call stack |
| Rewards | Badges for real milestones (no points or leaderboards), Sentry the owl, and a few easter eggs |
| Study log | Time in class, on study pages, on homework and in the code lab is logged by itself, only while the page is showing and the student is active. Time away from the portal is added with one tap. It all feeds the heatmap, streak and hours |
| Study hall | Opt-in: invited friends see each other's current course and weekly hours. No rankings |
| Online courses | Lesson pages with an AI tutor chat on the Claude API, progress, and a certificate of completion |
| Owner area | `/admin`: sync the transcript, create invites, open exercises early, students, courses and prices, enrollments |

## Privacy of the transcript

The owner pastes TRANSCRIPT.md into `/admin/transcript`. The portal keeps only the parsed numbers (day, hours, next gate, course rows and grades) and discards the text. The transcript is never committed to this repository.

## Run it locally

You need Ruby 3.3 and SQLite.

```sh
bundle install
bin/rails db:prepare          # creates the database and seeds courses and exercises
bin/fetch-ruby-wasm           # Ruby for the code lab and classroom (checksummed)
bin/fetch-pyodide             # Python for the classroom (checksummed)
bin/fetch-sqlite              # SQLite for the classroom's SQL tools (checksummed)
bin/dev                       # http://localhost:3000
```

The seed creates an owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, or prints a random password if you don't set one. It does this once: when an owner already exists it is left alone, so the owner can change their email and password on the Account page (`/portal/account`) and keep them across restarts. Optional settings:

- `ANTHROPIC_API_KEY` turns on the tutor. Without it, the tutor saves the question and replies that it's offline.
- `TUTOR_MODEL` picks the tutor's model: `claude-sonnet-5-5` (the default, cheaper) or `claude-opus-5-5`. Any other value uses the default.
- `TUTOR_DAILY_CAP` is how many questions a student may ask per course per day (default 40).
- `APP_TIME_ZONE` sets the day boundary for streaks (default Central Time).
- `RUBY_WASM_URL` overrides where the code lab loads Ruby from.

## Selling courses

A course is either free to every student in the portal (all of them, before PX1) or **sold** (`courses.paid`). A sold course has a public page at `/store/<slug>` and is opened only by the owner or by a student whose enrollment is active.

- **Price.** The owner sets it in cents at `/admin/courses` (2900 is $29.00). A sold course with no price, or one that isn't published, can't be bought. PX1 is seeded with no price and unpublished.
- **Buying.** "Buy" makes an account (or signs in), then the buyer ticks the terms box and pays on Stripe's page. The enrollment is created only when Stripe confirms the payment: by the webhook, or when the buyer lands back on the site and the session is read back from Stripe.
- **Webhook.** Point Stripe at `POST /webhooks/stripe` for `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `charge.refunded` and `charge.dispute.created`. Requests without a valid signature (`STRIPE_WEBHOOK_SECRET`, five-minute tolerance) are refused. A full refund or a dispute ends access.
- **Ending access.** `/admin/enrollments` lists every enrollment; "End access" revokes one. It does not refund: do that in the Stripe dashboard.
- **Accounts made by buying** see the store, their purchases and their account page. They don't get the classroom, code lab or tutors unless the owner opens the portal to them on their page in `/admin/users`.
- **PX1** ships as a finished player in `db/course_players/px1/` (see the README there), served at `/learn/px1/player`, with its practice files at `/learn/px1/downloads`. Neither is under `public/`.

Settings (all from the environment, never committed; see `.env.example`):

- `STRIPE_SECRET_KEY` turns checkout on. Without it the Buy button is disabled with a message. Start with a test key (`sk_test_...`).
- `STRIPE_WEBHOOK_SECRET` is the signing secret for the webhook (`whsec_...`).
- `BRAND_LEGAL_NAME`, `BRAND_POSTAL_ADDRESS` and a real `BRAND_CONTACT_EMAIL` are the seller's identity. Checkout that takes real money (a live key, or any key in production) stays blocked until all three are set.
- `STRIPE_TEST_IN_PRODUCTION=1` lets a test key work on the real site. Leave it off: with it on, anyone can "buy" with a Stripe test card.
- `STRIPE_TAX=1` adds Stripe Tax to checkout, once it is set up in the Stripe dashboard.

To try a test purchase on your Mac: start the portal with a test `STRIPE_SECRET_KEY` in its environment (nothing reads `.env` by itself, so use `STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_... bin/dev`, or the settings file your Docker install passes in), run `stripe listen --forward-to localhost:3000/webhooks/stripe` and copy the `whsec_...` it prints into `STRIPE_WEBHOOK_SECRET`, set a price on PX1 and publish it in `/admin/courses`, then buy it with card `4242 4242 4242 4242`.

The terms, refund policy and privacy policy carry Legal's v1.1 text (Nov 13, 2026). Two facts are still open and show in `[square brackets]` on the privacy page: the host and the PO box (never a street or home address). Fill them before taking real money, and set `POLICY_PUBLISH_DATE` (for example `November 24, 2026`) on go-live day: the 'Last updated' line on all three pages stays hidden until it is set.

The web fonts are served by the app itself (`app/assets/fonts/`, with each family's SIL Open Font License beside it), so the site makes no request to a font service.

### If the owner is locked out (Docker install)

The Mac install sends no email, so "Forgot your password?" can't help. From Terminal, with the portal container running:

```
# Which email does the owner sign in with? (catches a typo made on the Account page)
docker exec ironwood-portal bin/rails runner 'puts User.admin.pluck(:email_address)'

# Set the owner's email
docker exec ironwood-portal bin/rails runner 'User.admin.first.update!(email_address: ARGV[0])' you@example.com

# Set a new owner password. It asks for it and doesn't show or save what you type.
docker exec -it ironwood-portal bin/rails runner 'require "io/console"; User.admin.first.update!(password: IO.console.getpass("New owner password (10+ characters): ")); puts "Password changed."'
```

## Code lab assets

The editor bundle (`app/javascript/lab/editor.js`) and the Ruby, Python, JavaScript and SQL workers (`public/lab/ruby-worker.js`, `public/lab/python-worker.js`, `public/lab/js-worker.js`, `public/lab/sql-worker.js`) are built from `vendor/lab-src` and committed; `bin/build-lab-assets` rebuilds them (needs Node).

The Ruby binary (`public/lab/ruby.wasm`, about 30 MB) is not committed. `bin/fetch-ruby-wasm` downloads the pinned version and refuses it unless its SHA-256 matches. The Docker build runs it, so the binary always ships with the site. The worker checks the same SHA-256 before running Ruby, whether it came from this site or from the jsDelivr fallback.

Python is Pyodide, pinned in `vendor/lab-src/package.json`. `bin/fetch-pyodide` downloads the same version into `public/lab/pyodide` (about 13 MB, not committed) and refuses it unless the package's SHA-512 matches; the Docker build runs it. Python is only ever loaded from this site, never from a CDN. In the browser it has the standard library only: no pip, files or internet, so lessons do those parts as "on your Mac" steps.

JavaScript needs no download: the browser is the runtime. The student's code runs in a Web Worker (`vendor/lab-src/js-harness.js`), away from the page, with `console.log` captured.

The practice Terminal (`app/javascript/lib/terminal_sim.js`) is a pretend computer written in plain JavaScript, with its own Git: a staging area, commits, branches, merges and real conflicts. It has no remotes, so pushing and pulling stay on the student's Mac.

The web page editor (`web` mode) needs no download either. The student's HTML and CSS are drawn in a sandboxed frame (`sandbox="allow-same-origin"`, so no script runs, plus a content policy that fetches nothing from outside), and the page checks read that frame (`app/javascript/lib/page_preview.js`). Its tests run on jsdom, a dev dependency of `vendor/lab-src`.

SQL is SQLite compiled for the browser (sql.js), pinned in `vendor/lab-src/package.json`. `bin/fetch-sqlite` downloads the same version's binary into `public/lab/sqlite` (under 1 MB, not committed) and refuses it unless its SHA-256 matches; the Docker build runs it, and the worker checks the same hash before running it. It is only ever loaded from this site. Every fresh database starts with a small made-up library (`books`, `members`, `loans`) defined in `vendor/lab-src/sql-harness.js`.

Classroom lessons live in `db/seeds/lessons/*.md`, one file per lesson, in the faculty's lesson-script format (steps, checks and hints, never solutions). `ClassLessonMarkdown` parses them and `bin/rails db:seed` loads them.

Exercises live in `db/seeds/exercises/*.md`, one file per exercise, in the faculty's format. Re-run `bin/rails db:seed` after adding one.

## Tests

```sh
bin/rails test
bin/test-js                   # practice Terminal, checks, and the Ruby and Python harnesses in real Ruby and Python (needs Node)
bin/rubocop
bin/brakeman
```

## Deploy (Fly.io)

The chosen host. `fly.toml` holds the settings and [docs/DEPLOY-FLY.md](docs/DEPLOY-FLY.md) has the owner's steps, costs, backups and how to stop paying. On Fly the app also reads `FORCE_SSL=1` (HTTPS in front of the app) and `APP_HOST` (the public address); both are set in `fly.toml` and stay unset on the Mac.

## Deploy (Kamal)

Not in use; kept as a template.

1. Get a small Linux server (any VPS with Docker) and a domain, then point the domain at the server.
2. In `config/deploy.yml`, set the server IP, `proxy.host` to your domain, the registry, `ADMIN_EMAIL` and `BRAND_CONTACT_EMAIL`. To sell courses, also uncomment the Stripe and seller lines there and in `.kamal/secrets`.
3. Export the secrets listed in `.kamal/secrets` in your shell. Generate `SECRET_KEY_BASE` with `bin/rails secret`.
4. Run `bin/kamal setup` the first time, then `bin/kamal deploy` after that.

SQLite lives in the `storage` volume, so back it up (Litestream or a nightly copy).
