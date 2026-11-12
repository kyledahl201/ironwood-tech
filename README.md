# Ironwood Tech

The learning portal for **Ironwood Tech**, a non-profit personal university. Kyle is its first student; friends can join later by invitation. It sells nothing.

Ironwood is not an accredited school and grants no degrees or credit. The faculty are AI personas, and the site says so on every page.

## What's in the app

| Area | What it does |
| --- | --- |
| Public page | One page about the school, plus privacy. Search engines are told not to index it unless `ALLOW_INDEXING=1` |
| Accounts | Invite-only sign-up, sign in and password reset (Rails 8 authentication) |
| Today | The dashboard: today's class or lesson, the next gate countdown, the crest tree that lights up with progress, a 26-week study heatmap and a forgiving streak |
| Classroom | Lessons scripted by the faculty and played step by step: the professor's board on top, a workbench underneath with a practice Terminal (a pretend computer in the browser), a console and an editor for Ruby, and a console and an editor for Python. Tasks are checked as you type, hints come one at a time, "on your Mac" steps check pasted output, and quiz answers are checked on the server. Finishing a lesson counts as taught. Each lesson also has a study page (study guide, flashcards, the questions from class again) and homework that plays in the same workbench; handed-in homework waits for the professor, who grades it. "Copy for my tutor" copies the task, the student's work and the checks to paste into a chat with their professor. A course can ship a tutor kit (`db/tutor_kits/<course>/*.md`): Markdown files, with no answers, that a student downloads and adds to their own Claude project so the course's professor can coach them there |
| Code lab | Ruby exercises written by the faculty, with a real editor (CodeMirror), Ruby running in the browser (ruby.wasm), automatic checks, a line-by-line output diff and hints one at a time. Exercises open after their lesson is taught. No solutions are stored |
| Visualizers | Step-through tools in one frame: a loop tracer, a hash lookup and a method call stack |
| Rewards | Badges for real milestones (no points or leaderboards), Sentry the owl, and a few easter eggs |
| Study log | Time in class, on study pages, on homework and in the code lab is logged by itself, only while the page is showing and the student is active. Time away from the portal is added with one tap. It all feeds the heatmap, streak and hours |
| Study hall | Opt-in: invited friends see each other's current course and weekly hours. No rankings |
| Online courses | Lesson pages with an AI tutor chat on the Claude API, progress, and a certificate of completion |
| Owner area | `/admin`: sync the transcript, create invites, open exercises early, students and courses |

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

The seed creates an owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, or prints a random password if you don't set one. Optional settings:

- `ANTHROPIC_API_KEY` turns on the tutor. Without it, the tutor saves the question and replies that it's offline.
- `APP_TIME_ZONE` sets the day boundary for streaks (default Central Time).
- `RUBY_WASM_URL` overrides where the code lab loads Ruby from.

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

## Deploy (Kamal)

1. Get a small Linux server (any VPS with Docker) and a domain, then point the domain at the server.
2. In `config/deploy.yml`, set the server IP, `proxy.host` to your domain, the registry, `ADMIN_EMAIL` and `BRAND_CONTACT_EMAIL`.
3. Export the secrets listed in `.kamal/secrets` in your shell. Generate `SECRET_KEY_BASE` with `bin/rails secret`.
4. Run `bin/kamal setup` the first time, then `bin/kamal deploy` after that.

SQLite lives in the `storage` volume, so back it up (Litestream or a nightly copy).
