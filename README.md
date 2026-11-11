# Ironwood Tech

The learning portal for **Ironwood Tech**, a non-profit personal university. Kyle is its first student; friends can join later by invitation. It sells nothing.

Ironwood is not an accredited school and grants no degrees or credit. The faculty are AI personas, and the site says so on every page.

## What's in the app

| Area | What it does |
| --- | --- |
| Public page | One page about the school, plus privacy. Search engines are told not to index it unless `ALLOW_INDEXING=1` |
| Accounts | Invite-only sign-up, sign in and password reset (Rails 8 authentication) |
| Today | The dashboard: today's class or lesson, the next gate countdown, the crest tree that lights up with progress, a 26-week study heatmap and a forgiving streak |
| Code lab | Ruby exercises written by the faculty, with a real editor (CodeMirror), Ruby running in the browser (ruby.wasm), automatic checks, a line-by-line output diff and hints one at a time. Exercises open after their lesson is taught. No solutions are stored |
| Visualizers | A loop tracer that steps through `.each` line by line |
| Rewards | Badges for real milestones (no points or leaderboards), Sentry the owl, and a few easter eggs |
| Study log | Log study sessions; they feed the heatmap, streak and hours |
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
bin/dev                       # http://localhost:3000
```

The seed creates an owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, or prints a random password if you don't set one. Optional settings:

- `ANTHROPIC_API_KEY` turns on the tutor. Without it, the tutor saves the question and replies that it's offline.
- `APP_TIME_ZONE` sets the day boundary for streaks (default Central Time).
- `RUBY_WASM_URL` overrides where the code lab loads Ruby from.

## Code lab assets

The editor bundle (`app/javascript/lab/editor.js`) and the Ruby worker (`public/lab/ruby-worker.js`) are built from `vendor/lab-src` and committed. To rebuild them, or to get a local copy of the Ruby binary for offline use, run `bin/build-lab-assets` (needs Node). Without a local `public/lab/ruby.wasm`, the lab loads Ruby from the jsDelivr CDN.

Exercises live in `db/seeds/exercises/*.md`, one file per exercise, in the faculty's format. Re-run `bin/rails db:seed` after adding one.

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

SQLite lives in the `storage` volume, so back it up (Litestream or a nightly copy).
