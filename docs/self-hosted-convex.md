# Self-hosted Convex setup

This guide runs AgileKit under `/scrum` with self-hosted Convex and Caddy.
It intentionally excludes the Convex dashboard, Jira integration, Google sign-in,
and magic-link sign-in. The supported auth mode is anonymous guest sessions.

## Architecture

Public routes:

- `/scrum/*` goes to the Next.js frontend.
- `/scrum/api/*` goes to the Convex backend on container port `3210`.
- `/scrum/site/*` goes to Convex HTTP actions/auth on container port `3211`.

Why this split matters:

- Convex realtime client traffic, including websockets, uses the backend route.
- BetterAuth HTTP endpoints use the site route.
- Caddy strips `/scrum/api` and `/scrum/site` before proxying, so Convex still
  receives requests at the path shape it expects.
- Port `3211` is not exposed on the host because only Caddy and the frontend
  need to reach it inside Docker.

## Clone and install

```bash
git clone https://github.com/spokvulcan/poker-planning.git
cd poker-planning
npm install
```

Why this matters:

- `npm install` installs the Convex CLI and project dependencies used by
  `npx convex ...` commands.
- The frontend container uses `npm ci` during image builds, but local CLI
  deploys still need dependencies available on the machine running the command.

## Start Convex and Caddy

```bash
docker compose up -d backend caddy
```

Caddy exposes:

- `http://127.0.0.1/scrum` for the frontend path.
- `http://127.0.0.1/scrum/api` for Convex backend traffic.
- `http://127.0.0.1/scrum/site` for Convex auth HTTP routes.

The Convex container uses:

```CONVEX_CLOUD_ORIGIN=http://127.0.0.1/scrum/api
CONVEX_SITE_ORIGIN=http://backend:3211
```

Why this matters:

- `CONVEX_CLOUD_ORIGIN` is the public backend URL Convex reports to clients.
- `CONVEX_SITE_ORIGIN` is intentionally internal here. Convex validates auth
  JWTs by fetching BetterAuth JWKS from its site origin. Inside Docker,
  `http://backend:3211` is reachable and avoids looping through the public
  path proxy.
- Browser auth traffic still uses `http://127.0.0.1/scrum/site` through Caddy.

Check the backend:

```bash
curl http://127.0.0.1/scrum/api/version
```

Expected result:

- A successful HTTP response. The current image may return `unknown`; that is
  acceptable for this health check.

## Generate the Convex admin key

```bash
docker compose exec backend ./generate_admin_key.sh
```

Why this matters:

- The admin key lets the Convex CLI control this self-hosted deployment without
  Convex Cloud.
- Treat it like a secret. Do not commit it.
- The script prints the key; it does not create `.env.local` for you.
- If you run the script again, use the newest key for future CLI commands.

Create or update `.env.local` for local CLI convenience:

```bash
CONVEX_SELF_HOSTED_URL=http://127.0.0.1:3210
CONVEX_SELF_HOSTED_ADMIN_KEY=<generated admin key>
```

Why `.env.local` may not exist:

- Docker Compose already supplies frontend runtime variables directly from
  `docker-compose.yml`.
- The previous local deploy was run with `CONVEX_SELF_HOSTED_URL` and
  `CONVEX_SELF_HOSTED_ADMIN_KEY` set in the PowerShell process.
- `.env.local` is only a convenient place for the CLI to read those values on
  future commands. It is not required for containers already configured by
  Compose.

Use the direct backend URL for the CLI:

```text
CONVEX_SELF_HOSTED_URL=http://127.0.0.1:3210
```

Why not `/scrum/api`:

- Browser traffic should use `/scrum/api`.
- The local Convex CLI was not reliable through the path-prefixed Caddy route.
  The direct localhost backend port avoids that limitation.

## Configure frontend public URLs

The Compose file builds and runs the frontend with:

```text
NEXT_PUBLIC_SITE_URL=http://127.0.0.1/scrum
NEXT_PUBLIC_CONVEX_URL=http://127.0.0.1/scrum/api
NEXT_PUBLIC_CONVEX_SITE_URL=http://127.0.0.1/scrum/site
NEXT_PUBLIC_AUTH_URL=http://127.0.0.1/scrum/site/api/auth
```

Why this matters:

- `NEXT_PUBLIC_SITE_URL` is the canonical URL used for copied room links,
  metadata, and base-path-aware public assets.
- `NEXT_PUBLIC_CONVEX_URL` is where the browser connects for Convex realtime
  traffic.
- `NEXT_PUBLIC_CONVEX_SITE_URL` and `NEXT_PUBLIC_AUTH_URL` route BetterAuth
  anonymous sign-in through Caddy.
- If these are malformed, symptoms include broken copied links, failed
  anonymous sign-in, missing images, or Convex websocket connection failures.

## Set Convex server environment variables

Set these before deploying functions:

```bash
npx convex env set SITE_URL http://127.0.0.1/scrum
npx convex env set BETTER_AUTH_SECRET <32+ character secret>
```

On Windows PowerShell, generate a secret with:

```powershell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
```

Why this matters:

- Convex server environment variables are stored in the Convex deployment data,
  not in the frontend container and not in `.env.local`.
- `SITE_URL` tells the Convex auth module what the public app URL is.
- `BETTER_AUTH_SECRET` signs and validates BetterAuth sessions. Changing it
  invalidates existing sessions.
- Convex performs module analysis during deploy. That means the Convex runtime
  loads/analyzes your `convex/*.ts` modules to discover functions, schema,
  components, and environment-dependent configuration before making the deploy
  active. This app reads `SITE_URL` and `BETTER_AUTH_SECRET` at module load time
  in `convex/auth.ts`, so missing values can fail the deploy before requests
  ever reach the app.

If these are missing or malformed:

- Missing `BETTER_AUTH_SECRET` fails Convex function analysis/deploy.
- Missing `SITE_URL` fails Convex function analysis/deploy.
- A malformed `SITE_URL` can fail URL parsing.
- A wrong but parseable `SITE_URL` can cause auth cookies, trusted origins, or
  generated auth URLs to disagree with the browser-facing route.

Check current Convex env values:

```bash
npx convex env list
```

Use the same `CONVEX_SELF_HOSTED_URL` and `CONVEX_SELF_HOSTED_ADMIN_KEY` values
when running this command.

## Deploy Convex functions

```bash
npx convex deploy
```

Why this command:

- For self-hosted Convex, the CLI targets the self-hosted backend when
  `CONVEX_SELF_HOSTED_URL` and `CONVEX_SELF_HOSTED_ADMIN_KEY` are set.
- `npx convex deploy` is the one-shot command for pushing Convex functions to
  the target deployment.
- `npx convex dev` is also supported for development workflows; it runs a
  watch-style development loop. For this Docker Compose runbook, `deploy` is
  clearer because we want an explicit update step.

The official self-hosted guide documents using the generated admin key with the
CLI for pushing code, running queries, and importing data.

## Run the app

```bash
docker compose up --build
```

Open:

```text
http://127.0.0.1/scrum
```

Why this matters:

- `--build` rebuilds the Next.js image so public build-time variables are
  embedded into the client bundle.
- If only Convex code changed, rebuild the frontend only if frontend files or
  public env values also changed.

## Update Convex after backend code changes

```bash
npx convex deploy
```

Use the same self-hosted CLI variables:

```bash
CONVEX_SELF_HOSTED_URL=http://127.0.0.1:3210
CONVEX_SELF_HOSTED_ADMIN_KEY=<generated admin key>
```

Why this matters:

- Convex functions are deployed into the Convex backend. Rebuilding the
  frontend container does not update Convex functions.
- The CLI uses the direct localhost backend port because deploying through the
  `/scrum/api` path prefix is not reliable.

## Rebuild after frontend changes

```bash
docker compose build frontend
docker compose up -d frontend
```

Why this matters:

- Next.js public env vars are build-time inputs for browser code.
- If you change `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_CONVEX_URL`,
  `NEXT_PUBLIC_CONVEX_SITE_URL`, or `NEXT_PUBLIC_AUTH_URL`, rebuild the
  frontend image.

## Reset local Convex data

This deletes local rooms, users, votes, auth sessions, Convex env values, and
admin-key state stored in the Docker volume.

```bash
docker compose down -v
```

Then repeat:

- Start Convex and Caddy.
- Generate an admin key.
- Set Convex env values.
- Deploy Convex functions.
- Start the full app.

## Moving to AWS

The app code should not need to change if AWS keeps the same public path shape:

```text
https://<your-domain>/scrum
https://<your-domain>/scrum/api
https://<your-domain>/scrum/site
```

Expected AWS shape:

- ALB listener terminates TLS on `443`.
- ALB forwards `/scrum/*` traffic to Caddy on container or instance port `80`.
- Caddy routes to frontend, Convex backend, and Convex site/auth containers.
- Convex data is stored on durable storage.

Values to change for AWS:

```text
NEXT_PUBLIC_SITE_URL=https://<your-domain>/scrum
NEXT_PUBLIC_CONVEX_URL=https://<your-domain>/scrum/api
NEXT_PUBLIC_CONVEX_SITE_URL=https://<your-domain>/scrum/site
NEXT_PUBLIC_AUTH_URL=https://<your-domain>/scrum/site/api/auth
CONVEX_CLOUD_ORIGIN=https://<your-domain>/scrum/api
SITE_URL=https://<your-domain>/scrum
```

Values likely unchanged inside the Docker network:

```text
CONVEX_SITE_ORIGIN=http://backend:3211
CONVEX_URL_INTERNAL=http://backend:3210
CONVEX_SITE_URL_INTERNAL=http://backend:3211
```

AWS-specific notes:

- Use durable storage for `/convex/data`; for a single-container deployment,
  this usually means EBS mounted into the task/instance. Convex also documents
  options for external SQL and S3-backed storage for more production-oriented
  setups.
- Keep `3210` and `3211` private. The public entrypoint should be the ALB plus
  Caddy.
- Ensure the ALB supports websocket upgrades. Application Load Balancers support
  websockets, but idle timeout may need tuning for long-lived realtime sessions.
- If ALB terminates HTTPS and forwards HTTP to Caddy, keep public URLs as
  `https://...` because those are what browsers use.
- For production, remove `DO_NOT_REQUIRE_SSL=true` only after confirming the
  Convex backend receives the correct public HTTPS origins and proxy headers.

No app-code change should be needed unless:

- The public base path changes from `/scrum`.
- The backend route changes from `/scrum/api`.
- The auth/site route changes from `/scrum/site`.
- You want to re-enable Jira, Google OAuth, magic links, or the Convex dashboard.

