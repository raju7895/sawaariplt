# Sawaari — Setup Guide

Local auto-rickshaw booking platform: rider app, driver app and the Super Admin console, sharing one API and one PostgreSQL database.

---

## 1. Prerequisites

| | Version |
|---|---|
| Node.js | 18 or newer (20+ recommended) |
| PostgreSQL | 14 or newer (17 recommended) |
| npm | 9 or newer |

Check with `node -v`, `npm -v`, `psql --version`.

---

## 2. Fastest path (Windows)

```powershell
.\start-sawaari.ps1
```

Starts PostgreSQL (if it is installed as a service), the API and the web app,
then opens <http://localhost:5173>. Use `.\stop-sawaari.ps1` to shut it down.

If it reports that the API or the web app did not start, read `.logs\api.err.log`
and `.logs\web.err.log` — the usual cause is missing `npm install` or a missing
`server\.env`.

---

## 3. Manual install

### 3a. Database

**Option A — local PostgreSQL**

```bash
createdb sawaari
```

**Option B — Docker**

```bash
docker compose up -d      # PostgreSQL 17 on localhost:5432 (sawaari/sawaari)
```

---

## 4. API server

```bash
cd server
npm install
cp .env.example .env      # then edit .env (see below)
npm run setup              # migrations + seed (cities, pricing, settings, staff admin)
npm start                  # http://localhost:4000
```

### Configure `server/.env`

The only value you **must** change before production is the two secrets:

```ini
JWT_SECRET=<64+ random hex chars>      # openssl rand -hex 32
OTP_PEPPER=<48+ random hex chars>      # openssl rand -hex 24
```

Everything else has a working default. `SUPER_ADMIN_PASSWORD` is only needed if you want to choose the owner password yourself — otherwise `npm run seed:superadmin` generates a strong one and writes it to `server/backups/superadmin-credentials.txt`.

Optional integrations (the platform degrades gracefully without each one):

| Variable | Enables |
|---|---|
| `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / `RAZORPAY_WEBHOOK_SECRET` | Online card/UPI payments + gateway refunds |
| `SMS_PROVIDER` + `MSG91_*` or `TWILIO_*` | Real SMS OTPs (without it the OTP is printed to the console) |
| `SMTP_HOST/USER/PASS` | Email verification, password reset and notification emails |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Browser push notifications (in-app notifications always work) |

---

## 5. Web app

```bash
cd web
npm install
npm run dev                # http://localhost:5173
```

The dev server proxies `/api`, `/uploads` and `/socket.io` to `localhost:4000`.

**Production build**

```bash
npm run build              # → web/dist
```

Serve `web/dist` with any static host and point it at the API (see `README.md` →
*Production considerations* for CSP, HTTPS and the reverse-proxy setup).

---

## 6. The Super Admin account

```bash
cd server
npm run seed:superadmin
```

Creates the platform owner, links legacy staff accounts to the console, switches on
two-factor authentication and writes the one-time credentials to
`server/backups/superadmin-credentials.txt` (git-ignored).

**Store that file in a password manager, then delete it.** Sign in at
`http://localhost:5173/admin-login` with the email + password, then the 6-digit
authenticator code.

Forgot the password? `npm run admin:password` sets it from `SUPER_ADMIN_PASSWORD`
or generates a new one. `npm run admin:diagnose` shows exactly where a sign-in
stops, without printing any secret.

---

## 7. Verify the installation

```bash
cd server
node src/scripts/e2e-test.js        # rider + driver + admin journey (61 checks)
node src/scripts/test-admin-api.js   # admin console + RBAC + audit trail (64 checks)
node src/scripts/sweep-admin-api.js  # every admin endpoint + CSV exports (43 checks)
node src/scripts/sweep-frontend.js   # imports, routes, dead components
node src/scripts/db-integrity.js     # migrations, foreign keys, orphans
```

---

## 8. Common problems

| Symptom | Cause / fix |
|---|---|
| `ECONNREFUSED localhost:5432` | PostgreSQL is not running, or `DATABASE_URL` is wrong |
| OTP not received | `SMS_DEV_MODE=true` — the code is in the server console and in the API response (`devCode`) |
| Super Admin password rejected | `SUPER_ADMIN_PASSWORD` may have been truncated by a `#` or quote in `.env`. Run `npm run admin:password`, then `npm run admin:verify` |
| "Too many failed sign-in attempts" | The rate limiter tripped. Wait 15 minutes, restart the API, or raise `ADMIN_LOGIN_RATE_LIMIT` / `ADMIN_2FA_RATE_LIMIT` for testing |
| "No road route found" / fares fail | OSRM is unreachable → the platform falls back to a labelled straight-line estimate. Self-host OSRM for production |
| Map tiles missing | The browser needs internet access for CARTO/OSM tiles |
| Driver location missing | Browser geolocation permission denied — the driver can use **Set on map** in the driver console |
