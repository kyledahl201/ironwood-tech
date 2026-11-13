# Putting the portal on Fly.io

The owner's steps, in order. Each step is one command or one click: paste them **one at a time** and read what comes back before the next. Nothing here has been run yet, and no account exists.

- **Address:** `https://ironwoodtech.org` (the site moved from `learn.ironwoodtech.org` to the root domain; `APP_HOST` in `fly.toml` says so, and email links use it). The certificate steps in Part 4 still name the old subdomain: for the root domain, run them with `ironwoodtech.org` and follow what `fly certs setup` prints (a root domain uses A and AAAA records, not a CNAME).
- **Where:** one small machine in Dallas (`dfw`) with a 1 GB disk for the database.
- **Settings:** `fly.toml` in this repository. Nothing in it is secret.
- **Never paste a password or key into this file, a chat or a commit.** The steps below put them straight into Fly from your Terminal.

Checked against Fly's documentation on 2026-11-13. Anything that could not be checked is marked **not verified**.

## What it costs

Every price is from Fly's pricing page, <https://fly.io/docs/about/pricing/>, read on 2026-11-13, unless the row says "assumption".

| Item | Price | For this site |
| --- | --- | --- |
| Machine, shared-cpu-1x with 512 MB, running all month | $3.69 a month in Fly's two lowest-priced regions (Virginia and New Jersey). From Fly's pricing page on 2026-11-13 | Billed by the second, only while running. **Dallas price: assumption.** The page says "Machine prices vary by region" and its table for other regions did not load, so Dallas may be higher. Check it at <https://fly.io/calculator> before step 5 |
| Machine while stopped | $0.15 per GB of its disk image a month. From Fly's pricing page on 2026-11-13 | About $0.15 to $0.30. Image size is an assumption (1 to 2 GB) |
| Volume (the database disk) | $0.15 per GB a month, attached or not. From Fly's pricing page on 2026-11-13 | $0.15 for 1 GB |
| Daily volume snapshots | $0.08 per GB a month of stored data, first 10 GB free. From Fly's pricing page on 2026-11-13 | $0 |
| Certificate for learn.ironwoodtech.org | $0.10 a month each, first 10 free. From Fly's pricing page on 2026-11-13 | $0 |
| Shared IPv4 and IPv6 addresses | Free. From Fly's pricing page on 2026-11-13 | $0. Don't add a dedicated IPv4 ($2 a month) |
| Data sent to visitors | $0.02 per GB in North America. From Fly's pricing page on 2026-11-13 | Cents |
| Building the image on Fly's builder | **Assumption:** no charge. Not found on the pricing page | $0 |

**Estimate as configured** (the machine stops when nobody is using the site): about **$1 to $2 a month**. Example: two hours of use a day is about $0.31 of machine time at the $3.69 rate, plus about $0.45 of disk.

**If you switch it to always on:** about **$4 to $5 a month** at the lowest-region rate, more if Dallas is priced higher.

Also from the pricing page on 2026-11-13: a new account gets "$1 of credit ... which lasts for 7 days or until you use it up", a card is required after that, and "if your personal organization's monthly bill comes to less than $5, we waive it". Don't plan around the waiver; Fly can change it.

Not included: the AI tutor's use of the Claude API, which Anthropic bills separately, and the domain name.

**Steps that cost money:** step 5 (the volume, from the minute it is created) and step 12 (the machine, from the first deploy). Everything before step 5 is free. Steps 15 to 18 (certificate and DNS) add nothing.

## What you trade for the low price

`fly.toml` lets Fly stop the machine after a few idle minutes.

- The first visit after a quiet spell waits while the site starts. Expect something like 15 to 60 seconds (**not measured**: it could not be tried before the first deploy). After that it is fast until it goes idle again.
- Nothing runs while it is stopped. The nightly deletion of old tutor chats therefore also runs every time the site starts, so the promise on the privacy page still holds.
- The database is safe either way: Fly asks the server to shut down cleanly, one disk can only be attached to one machine, and SQLite survives a hard stop.
- **Not verified:** whether Fly counts an open tutor chat as activity. If a tutor answer ever goes missing after a long pause, switch to always on.

To keep it always on: in `fly.toml` change `auto_stop_machines = "stop"` to `auto_stop_machines = "off"`, then run step 12 again.

## Part 1: set up (free until step 5)

**1. Install Fly's command-line tool.**

```sh
brew install flyctl
```

**2. Create your Fly account.** This opens the browser. Fly will ask for a card at some point.

```sh
fly auth signup
```

Later, on another day or another Mac, sign in with `fly auth login` instead.

**3. Go to the project folder.** Every command after this must be run from here, because that is how Fly finds `fly.toml`. Change the path if your copy is somewhere else.

```sh
cd ~/ironwood-tech
```

**4. Create the app. This deploys nothing and costs nothing.**

```sh
fly apps create ironwood-portal
```

If Fly says the name is taken, pick another (for example `ironwood-portal-kd`), use it in this command, and change the `app = "ironwood-portal"` line at the top of `fly.toml` to match. Wherever a later step says `ironwood-portal`, use your name.

**5. Create the database disk. Billing starts here: $0.15 a month.**

```sh
fly volumes create ironwood_storage --region dfw --size 1 --snapshot-retention 14 --yes
```

Fly will warn that one volume is not redundant. That is expected: the daily snapshots are the backup (see "Backups").

## Part 2: secrets (free)

Each secret is stored at Fly and never shown again. `--stage` saves it without starting anything.

**6. The app's signing key.** Your Mac makes a random one and hands it straight to Fly. You never see it and don't need to keep it.

```sh
fly secrets set --stage SECRET_KEY_BASE="$(openssl rand -hex 64)"
```

**7. The owner's sign-in email.** Type your real address in place of `you@example.com`.

```sh
fly secrets set --stage ADMIN_EMAIL=you@example.com
```

**8. The contact address shown on the site.** Again, your real one.

```sh
fly secrets set --stage BRAND_CONTACT_EMAIL=hello@example.com
```

**9. The owner's password, in three commands, so it never appears on screen or in your Terminal history.** It needs 10 characters or more. First, this waits for you to type it and press Return (nothing shows while you type):

```sh
read -s "IRONWOOD_SECRET?Owner password, then Return: "
```

Then send it to Fly:

```sh
fly secrets set --stage ADMIN_PASSWORD="$IRONWOOD_SECRET"
```

Then forget it:

```sh
unset IRONWOOD_SECRET
```

The email and password are only used the first time the site starts, to create the owner account. After that, change them on the Account page.

**10. Optional: the AI tutor's key.** Same three commands. Skip this and the tutor says it is offline.

```sh
read -s "IRONWOOD_SECRET?Anthropic API key, then Return: "
```

```sh
fly secrets set --stage ANTHROPIC_API_KEY="$IRONWOOD_SECRET"
```

```sh
unset IRONWOOD_SECRET
```

**11. Check the names are there.** This lists names only, never values.

```sh
fly secrets list
```

You should see `SECRET_KEY_BASE`, `ADMIN_EMAIL`, `BRAND_CONTACT_EMAIL`, `ADMIN_PASSWORD`, and `ANTHROPIC_API_KEY` if you did step 10. Stripe keys come later, the same way, when checkout is ready.

## Part 3: first deploy

**12. Deploy. Machine billing starts here.** It takes several minutes: Fly builds the image, starts one machine and attaches the disk. `--ha=false` means one machine, not two. **Always include it:** two machines cannot share one SQLite database.

```sh
fly deploy --ha=false
```

**13. Check it is running.**

```sh
fly status
```

**14. Open the health page.** A plain green page means the app is up.

```sh
open https://ironwood-portal.fly.dev/up
```

Then open `https://ironwood-portal.fly.dev` and sign in with the owner email and password from steps 7 and 9.

This is a **new, empty database**. Nothing from the Mac install comes across by itself. Moving that data over is a separate job; ask Tech before you rely on the new site.

## Part 4: the real address (free)

**15. Ask Fly for the certificate.**

```sh
fly certs add learn.ironwoodtech.org
```

**16. Read the DNS record Fly wants.** The same instructions, any time:

```sh
fly certs setup learn.ironwoodtech.org
```

**17. Add that record where ironwoodtech.org is registered.** One click path: DNS settings, Add record. Expect it to be:

| Type | Name (host) | Value (points to) | TTL |
| --- | --- | --- | --- |
| CNAME | `learn` | the target Fly printed in step 16 | default |

Copy the value **exactly as Fly printed it**. Fly's docs say each app has its own target, so it is not written here. If Fly prints `A` and `AAAA` records as well, the CNAME alone is enough for a subdomain. If the registrar offers a "proxy" switch (Cloudflare's orange cloud), leave it off.

**18. Check the certificate.** Repeat every few minutes until it says it is issued. DNS can take up to an hour.

```sh
fly certs check learn.ironwoodtech.org
```

Then open <https://learn.ironwoodtech.org>.

## Turn on email (Resend)

The site emails gift links and password resets. Until this is done nothing is sent and nothing breaks: the owner area shows each gift link once, for you to send yourself, and password reset emails don't go out.

Resend's free plan, from resend.com/pricing on 2026-11-13: 3,000 emails a month, at most 100 a day, 3 domains, 30 days of logs, ticket support only. Check the page again before you rely on it.

**1. Make a Resend account** at <https://resend.com> (sign up with your business email).

**2. Add the domain.** In Resend, open **Domains**, press **Add Domain**, type `ironwoodtech.org`. Resend shows a short list of DNS records (an MX and TXT records for sending, and a DKIM TXT record). Leave that page open.

**3. Add those records at Porkbun.** Sign in to Porkbun, open **Domain Management**, find `ironwoodtech.org`, press **DNS**. For each record Resend lists, add one with the same **Type**, **Host** and **Answer/Value**. Porkbun adds `.ironwoodtech.org` to the host by itself, so type only the part before it (for example `send`, or `resend._domainkey`). Copy the values exactly. Don't touch the records Fly needs for the site.

**4. Verify.** Back in Resend, press **Verify DNS Records**. It can take from a few minutes to a few hours. Wait until the domain says **Verified**.

**5. Make an API key.** In Resend, open **API Keys**, press **Create API Key**, name it `ironwood-portal`, permission **Sending access**, domain `ironwoodtech.org`. Copy it. Resend shows it only once.

**6. Put the key into Fly without it ever showing on screen or in your shell history.** Three commands. The first one waits, hidden, for you to paste the key and press Return:

```sh
read -s "IRONWOOD_SECRET?Resend API key, then Return: "
```

This hands the key to Fly on its input, not on the command line (`printf` is built into the shell, so the key never appears in the list of running programs). Fly restarts the site with it:

```sh
printf 'RESEND_API_KEY=%s\n' "$IRONWOOD_SECRET" | fly secrets import
```

```sh
unset IRONWOOD_SECRET
```

**7. Optional: the sender's name and address.** Without it, mail comes from `Ironwood Tech <hello@ironwoodtech.org>`. The address must be on the domain you verified. Not secret, so it can be set directly:

```sh
fly secrets set MAIL_FROM="Ironwood Tech <hello@ironwoodtech.org>"
```

**8. Check.** The owner area's first page should now say **Email: on**. Send yourself a gift from **Gifts** to see the email arrive.

## Day to day

**Deploy a new version** (after `git pull`):

```sh
fly deploy --ha=false
```

The site is down for a minute or so while the one machine is replaced. Database changes are applied when the new version starts, on the machine that has the disk.

**See the logs** (Control-C to stop watching):

```sh
fly logs
```

**Roll back to the previous version.** First list the versions and their image names:

```sh
fly releases --image
```

Then deploy the one from before the problem, pasting its image name in place of the example:

```sh
fly deploy --ha=false --image registry.fly.io/ironwood-portal:deployment-EXAMPLE
```

This puts back the old code only. It does not undo database changes or `fly.toml` and secret changes. If the bad version changed the database, restore a snapshot too.

## Backups

Fly takes a snapshot of the disk **once a day, automatically**. This setup keeps each for **14 days** (Fly's default is 5, the most is 60). Snapshots cost $0.08 per GB a month with the first 10 GB free, so $0 here (pricing page, 2026-11-13). Source: <https://fly.io/docs/volumes/snapshots/>.

What that does and doesn't cover:

- You can lose up to a day of work: whatever changed since the last snapshot.
- Snapshots live at Fly, with the disk. Fly's own docs say they are not a substitute for your own backups. If the account or the app is deleted, they go too.
- A copy on your Mac now and then would close that gap. That step is **not written yet** because it could not be tested before the first deploy; ask Tech once the site is live.

**Take an extra snapshot before anything risky.** Find the volume's id (starts with `vol_`):

```sh
fly volumes list
```

```sh
fly volumes snapshots create vol_EXAMPLE
```

### Restore a snapshot

This replaces the live database with an older copy. Everything since that snapshot is lost. These commands are from Fly's docs but have **not been rehearsed on this app**; do it once for practice before real students depend on the site.

1. Find the current volume's id:

   ```sh
   fly volumes list
   ```

2. List its snapshots and pick one by date:

   ```sh
   fly volumes snapshots list vol_EXAMPLE
   ```

3. Make a new disk from that snapshot (adds $0.15 a month until step 7):

   ```sh
   fly volumes create ironwood_storage --snapshot-id vs_EXAMPLE --size 1 --region dfw --snapshot-retention 14 --yes
   ```

   It prints the new volume's id. Keep it.

4. Find the machine's id:

   ```sh
   fly status
   ```

5. Start a copy of the machine on the restored disk:

   ```sh
   fly machine clone MACHINE_ID --region dfw --attach-volume vol_NEW:/rails/storage
   ```

6. Straight away, remove the old machine, so only the restored one is serving:

   ```sh
   fly machine destroy MACHINE_ID --force
   ```

7. Open the site and check it. When you are sure, delete the old disk (this cannot be undone):

   ```sh
   fly volumes destroy vol_OLD
   ```

## Stop spending money

**It already costs almost nothing when idle:** the machine stops by itself and only the disks are billed (about $0.45 a month).

**Pause it completely, keep the data.** This removes the machine and keeps the disk and its snapshots ($0.15 a month):

```sh
fly scale count 0
```

To bring it back, run `fly deploy --ha=false`. **Not verified:** Fly's docs say `fly scale count` re-uses an unattached disk but don't say the same for `fly deploy`. After bringing it back, run `fly volumes list`: there should be one volume and it should be attached. If there are two, stop and ask Tech before doing anything else.

**End it for good.** This deletes the app, and with it the database and the snapshots (**assumption:** Fly's page for this command doesn't list what is deleted; check the dashboard afterwards for leftover volumes). Billing stops. It cannot be undone.

```sh
fly apps destroy ironwood-portal
```

Then delete the `learn` CNAME record at the registrar.

## If something goes wrong

- **The deploy fails on the health check.** Run `fly logs` and read the last lines. A missing `SECRET_KEY_BASE` (step 6) is the most likely cause.
- **The logs say it can't write to `/rails/storage`.** Fly staff say a new volume is handed to the image's user automatically (<https://community.fly.io/t/fly-volumes-getting-permission-denied/1773>), but that is a forum answer, not the docs, so it is **not verified**. Ask Tech.
- **The logs say it ran out of memory.** In `fly.toml` change `memory = "512mb"` to `memory = "1gb"` and deploy. That machine is $6.70 a month running full time at the lowest-region rate (pricing page, 2026-11-13).
- **"Forgot your password?" sends nothing.** The site has no outgoing email yet, on Fly or on the Mac. Ask Tech to reset the owner password.
- **Never run `fly scale count 2`** or deploy without `--ha=false`.

## What Tech read

Fly documentation, 2026-11-13:

- Configuration reference: <https://fly.io/docs/reference/configuration/>
- Pricing: <https://fly.io/docs/about/pricing/>
- Regions: <https://fly.io/docs/reference/regions/>
- Volumes: <https://fly.io/docs/volumes/overview/>, <https://fly.io/docs/volumes/snapshots/>, <https://fly.io/docs/volumes/volume-manage/>
- Rails with SQLite: <https://fly.io/docs/rails/advanced-guides/sqlite3/>
- Stopping and starting machines: <https://fly.io/docs/launch/autostop-autostart/>
- Custom domains: <https://fly.io/docs/networking/custom-domain/>
- Secrets: <https://fly.io/docs/apps/secrets/>
- Rolling back: <https://fly.io/docs/blueprints/rollback-guide>
- Scaling: <https://fly.io/docs/launch/scale-count/>
- Installing and signing in: <https://fly.io/docs/flyctl/install/>, <https://fly.io/docs/getting-started/sign-up-sign-in/>
