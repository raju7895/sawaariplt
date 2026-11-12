# 🛺 Sawaari — Local Auto-Rickshaw Booking Platform

A complete, production-ready web platform that connects passengers with nearby verified auto-rickshaw drivers. Real database, real maps, real-time tracking, and real payment flows — not a demo with fake data.

**Live locally:** API on `http://localhost:4000`, web app on `http://localhost:5173`.

---

## 🛡️ Super Admin — Master Control

The admin console is **part of the same application**, talking to the same API and the same database as the rider and driver apps. There is no separate admin website.

### The owner account

| | |
|---|---|
| Email | `utkarshbajpai077@gmail.com` (override with `SUPER_ADMIN_EMAIL`) |
| Role | `SUPER_ADMIN` — full platform control, every permission |
| Protection | The owner can never be suspended, deactivated, demoted or deleted (enforced by a database trigger, not just the UI) |

**Create it securely:**

```bash
cd server
npm run seed:superadmin                 # create or repair the owner account
npm run seed:superadmin -- --rotate    # reset its password + 2FA
```

* The password is a **deployment secret**: set `SUPER_ADMIN_PASSWORD` in `server/.env` or your secret manager. If it is empty, the seed script generates a cryptographically strong one-time password and writes it to `server/backups/superadmin-credentials.txt` (git-ignored). It is never hardcoded, never returned by an API and never written to a log.
* Passwords are stored only as **bcrypt hashes (cost 12)**. Two-factor secrets are encrypted with **AES-256-GCM** at rest.
* The seed also writes the TOTP secret, an `otpauth://` URI and single-use backup codes to the same local file — store them in a password manager, then delete the file.

### Signing in

`/admin-login` → **email + password → 6-digit authenticator code**. Every administrator account has:

* **Mandatory email verification** — a one-time link; sign-in is refused until it is used.
* **Mandatory two-factor authentication** — TOTP (Google Authenticator / Authy / 1Password) or a single-use backup code.
* **Login attempt limiting + temporary lockout** — 5 failures in 15 minutes blocks the source; 5 failures on one account lock that account for 30 minutes. A **correct** password is never refused by the shared counters.
* **Server-side sessions** — every session is a tracked row. Signing out, changing a password, a suspension or a 2FA reset invalidates every device immediately. Sessions expire after 12 hours (2-hour idle window).

#### If you cannot sign in

```bash
npm run admin:diagnose     # prints exactly where the sign-in stops (no secrets)
npm run admin:password     # set/rotate the owner password securely
```

`admin:diagnose` checks, in order: the account row, the hash algorithm and cost, the bcrypt comparison, the password step, the 2FA step and the issued session — and never prints a password, hash or token.

**The password lives in exactly one place: `SUPER_ADMIN_PASSWORD` in `server/.env`** (git-ignored). `npm run admin:password` applies it, invalidates every session and re-checks that the value survived the `.env` parser. If the value contains `#`, a quote, a backslash or a space it is **truncated by the parser** — the script refuses such a value and the API prints a warning at boot:

```
⚠ SUPER_ADMIN_PASSWORD does not match the stored password for …
  The .env value was probably truncated by a "#" or a quote. Fix it and run:
    npm run admin:password
```

Use letters, digits and `!@%^*-_=+` only.

### Roles and permissions

| Role | Scope |
|---|---|
| `SUPER_ADMIN` | Every permission; the only role that may grant elevated privileges |
| `ADMIN` | General platform management |
| `FINANCE_ADMIN` | Payments, revenue, commissions, refunds, financial reports |
| `SUPPORT_ADMIN` | Complaints, tickets, user support |
| `DRIVER_MANAGER` | Driver verification and fleet management |
| `MODERATOR` | Reports and user moderation |

35 granular permissions (`users.block`, `payments.refund`, `finance.settings`, `admins.create`, `audit.view`, …) are defined server-side in `server/src/services/rbac.js`. **Every route re-checks the permission on the server** — a Finance Admin cannot reach Super Admin credentials, a Support Admin cannot touch confidential financial settings, and a Driver Manager cannot change gateway credentials. The sidebar only shows what a role may use; the API enforces the truth.

### Audit log

Every administrative action is written to `admin_audit_log` with: admin id, admin email, admin role, action, category, target, **previous value**, **new value**, IP address, user agent, result (`success` / `failure` / `denied`) and a timestamp.

The table has a database trigger that **raises an exception on any UPDATE or DELETE** — the log is append-only for everyone, including the Super Admin. Entries are visible in **Admin → Audit Logs** with filters and CSV export.

### Console sections

Overview · Users · Drivers · Driver Verification · Bookings · Live Rides · Payments · Revenue & Earnings · Refunds · Reports & Complaints · Support · Admin Management · Analytics · Cities & Locations · Pricing Management · Notifications · Audit Logs · Platform Settings · Security Settings

### Financial integrity

* Revenue is computed from the `driver_earnings` ledger — it is never edited to look better.
* **Refunds create new `refunds` rows** that reference the original payment; the payment row itself is never modified.
* Gateway refunds go through the Razorpay API and store the provider reference. When the gateway is not configured the console refuses to pretend and tells you to settle it manually with the original payment channel.
* Gateway, SMS, SMTP and push credentials live in environment variables only — never in the database, never sent to the browser (the console shows a masked key id and a "configured / not configured" status).

### Backups

```bash
npm run db:backup      # pg_dump into server/backups/ (git-ignored)
```

Run this before any structural change. Migrations are additive, so restoring the dump is the rollback.

---

## 📱🖥️ Installable apps

The same codebase ships as three installable clients — all pointing at **one API and one database**:

| Client | Artifact | How to install |
|---|---|---|
| **Android** | `dist-android/LocalAutoBooking.apk` | Copy to the phone → allow "unknown sources" → install → set your server address in *Server settings* |
| **Windows** | `dist-windows/LocalAutoBooking-Setup.exe` | Run the installer (per-user, no admin rights) |
| **Windows portable** | `dist-windows/LocalAutoBooking-Portable.exe` | Double-click — runs from a temp folder, installs nothing |
| **PWA** | served from `web/dist` | Chrome/Edge → install from the address bar or the ⋮ menu |

The installed apps resolve the API in this order: a **Server settings** address saved
on the device → `VITE_API_URL` baked in at build time → the origin the app was opened
from. That means one APK works against a laptop on your LAN today and a hosted API
tomorrow, with no rebuild.

Full build instructions, toolchain setup and signing details:
**[`BUILD-AND-INSTALL.md`](BUILD-AND-INSTALL.md)**.

---

## ▶ Running it on your PC

### One click (Windows)

```powershell
# right-click → "Run with PowerShell", or:
powershell -ExecutionPolicy Bypass -File .\start-sawaari.ps1
```

It checks PostgreSQL, starts the API and the web app, waits until both are
healthy and opens your browser. `.\stop-sawaari.ps1` shuts it down again
(PostgreSQL keeps running as a Windows service).

| | |
|---|---|
| Rider / driver app | <http://localhost:5173> |
| Super Admin console | <http://localhost:5173/admin-login> |
| API | <http://localhost:4000> · health at `/api/health` |

### Manually

```bash
cd server && npm start        # API on :4000
cd web    && npm run dev      # web app on :5173
```

### On another computer

Unzip `sawaari-platform.zip` and follow **SETUP.md** — it walks through
Node, PostgreSQL, `npm install`, the migrations, the seed and the
Super Admin account, plus a troubleshooting table.

---

### Passengers
- **Mobile OTP signup/login** (hashed, 10-minute expiry) + JWT sessions
- **Live interactive map** (Leaflet + OpenStreetMap/CARTO tiles) with GPS location, address search (Nominatim geocoding), saved places
- **Nearby driver discovery** with real road distance (OSRM routing), not straight-line guesses
- **Book now / schedule for later / custom pickup point** with full ride lifecycle: *searching → assigned → arriving → arrived → in progress → completed*
- **Ride OTP** — the driver cannot start the ride until the passenger tells them the 4-digit code
- **Fare breakdown** before booking (base + per-km + per-minute + time-of-day surge, per city & vehicle type)
- **Pay by UPI QR / UPI intent / Razorpay / cash** — payments stay *pending* until a human (or Razorpay webhook) verifies them. Nothing is marked paid on a button click.
- **Share trip** — a public tracking link with live driver position, viewable without login
- **SOS alert** (location sent to admin), report user, in-app chat with the driver, reviews & ratings
- Ride history, payment history, support tickets with replies

### Drivers
- **Verification gate** — submit vehicle + license + RC documents; admin must approve before accepting rides
- **Online/offline toggle** with continuous GPS broadcast (browser geolocation watch → socket, throttled)
- **Manual position fallback** — if GPS is blocked or the device has no location, the driver drops a pin on the map and that position streams to passengers instead
- **Incoming ride requests** pushed in real time with pickup distance, fare, and accept/skip — with a polling fallback so a request is never missed because the driver was on another screen
- **Ride action bar**: arriving → arrived → start (passenger OTP) → complete
- **Earnings dashboard** with chart + ledger, ride history, reviews, UPI ID setup (admin-verified)
- Cannot be double-booked — accepting a ride locks the driver

### Admin
- Dashboard overview with stats + "needs attention" strip (pending drivers, UTR payments, open SOS/tickets)
- Driver approval queue with document review, reject with reason, UPI verification
- User management (search/filter/paginate/block/unblock)
- Bookings with filters + cancel + CSV export
- Payments: verify/reject UTRs, Razorpay captures, issue refunds
- Analytics (rides/fare trends, top drivers, payment mix)
- Cities + per-city, per-vehicle-type pricing editor
- Platform settings: commission %, search radius, request timeout, cancellation fee, support phone, SOS number
- Support tickets with threaded replies, user reports, SOS alerts with acknowledge/resolve
- CSV exports for bookings / users / drivers / payments

### Safety & Platform
- Role-based access control (passenger/driver/admin) enforced on every route
- Rate limiting on auth endpoints, bcrypt password hashing, zod input validation everywhere
- In-app real-time notifications (Socket.IO) + optional Web Push (VAPID)
- Cancellation policy with configurable free window and fee
- Scheduled-ride scheduler, ride expiry, stale-search cleanup (15s tick)
- Honest fallbacks: every third-party service reports its status on `/api/health` and degrades gracefully when unconfigured

---

## 🧱 Tech Stack

| Layer      | Tech |
|------------|------|
| Frontend   | React 18 + Vite, React Router, Tailwind CSS, Leaflet (react-leaflet), Recharts, lucide-react, socket.io-client |
| Backend    | Node.js + Express, Socket.IO, zod, multer, jsonwebtoken, bcryptjs, express-rate-limit |
| Database   | PostgreSQL (plain SQL through `pg`; no ORM) |
| Maps       | Leaflet + OSM/CARTO tiles, Nominatim geocoding, OSRM routing — **no API keys required** |
| Payments   | Razorpay REST API + webhook HMAC verification, direct UPI (`upi://pay` intent + dynamic QR via `qrcode`), cash |
| SMS/OTP    | Pluggable: dev-mode (default) / MSG91 / Twilio |
| Email      | nodemailer SMTP (optional) |
| Push       | Web Push via VAPID keys (optional) |

---

## 🚀 Quick Start (local development)

### Prerequisites
- **Node.js 18+**
- **PostgreSQL 14+** running locally (a database named `sawaari`)

### 1. Backend

```bash
cd server
npm install
```

Create `.env` (see [Configuration](#configuration) below), then:

```bash
npm run setup        # runs migrations + seed (admin, 10 cities, pricing, settings)
npm run dev          # or: npm start   (API on http://localhost:4000)
```

Verify: `curl http://localhost:4000/api/health` → `{"ok":true,...}`

### 2. Frontend

```bash
cd web
npm install
npm run dev          # web app on http://localhost:5173 (proxies /api, /uploads, /socket.io to :4000)
```

### 3. First users

The seed creates a staff administrator (values from `.env`):

| Role    | Email / Phone          | Password     |
|---------|------------------------|--------------|
| Staff   | `admin@sawaari.local`  | `Admin@12345`|

Everyone else registers through the app. With `SMS_DEV_MODE=true`, the OTP is:
- shown in the **server console**: `[sms:DEV] to 9999999999: 123456 is your Sawaari verification code…`
- returned in the API response body as `devCode`

> ⚠️ Turn `SMS_DEV_MODE=false` and configure a real SMS provider before any real deployment.

### 4. The platform owner

```bash
cd server
npm run seed:superadmin
```

This creates (or repairs) the `SUPER_ADMIN` owner account, links any legacy `admin` accounts to the console, switches on two-factor authentication and writes the one-time credentials to `server/backups/superadmin-credentials.txt`.

Then sign in at **http://localhost:5173/admin-login**.

---

## ⚙️ Configuration

All configuration lives in `server/.env`. Copy the block below and fill in what you need — **every third-party service is optional and degrades gracefully**:

```ini
PORT=4000
NODE_ENV=development
APP_URL=http://localhost:5173

# Database (required)
DATABASE_URL=postgres://postgres:postgres@localhost:5432/sawaari

# Security (required — generate with: openssl rand -hex 32)
JWT_SECRET=change-me-long-random-string
OTP_PEPPER=change-me-too

# Admin bootstrap (created by `npm run seed`)
ADMIN_EMAIL=admin@sawaari.local
ADMIN_PASSWORD=Admin@12345
ADMIN_PHONE=9999999999

# Platform owner — created by `npm run seed:superadmin`
# The password is the single source of truth; keep it out of git.
SUPER_ADMIN_EMAIL=utkarshbajpai077@gmail.com
SUPER_ADMIN_PASSWORD=
SUPER_ADMIN_NAME=Utkarsh Bajpai
ADMIN_TOTP_ENCRYPTION_KEY=        # encrypts TOTP secrets at rest (falls back to JWT_SECRET)

# Administrator security policy
ADMIN_MAX_LOGIN_ATTEMPTS=5
ADMIN_LOCKOUT_MINUTES=15
ADMIN_MAX_FAILED_ATTEMPTS=5
ADMIN_ACCOUNT_LOCK_MINUTES=30
ADMIN_SESSION_HOURS=12
ADMIN_INVITE_EXPIRY_HOURS=72
# Request-rate limits per source address (raise only in a test environment)
ADMIN_LOGIN_RATE_LIMIT=20
ADMIN_2FA_RATE_LIMIT=30

# OTP delivery
SMS_DEV_MODE=true            # true = OTP visible in logs/responses (dev only!)
SMS_PROVIDER=none            # none | msg91 | twilio
MSG91_AUTH_KEY=
MSG91_SENDER_ID=SAWAAR
MSG91_TEMPLATE_ID=
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM=

# Email (optional — ticket/receipt notifications)
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_FROM=Sawaari <no-reply@sawaari.local>

# Razorpay (optional — enables online card/UPI payments)
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=     # dashboard webhooks: payment.captured, refund.processed

# Web Push (optional — `npm run generate:vapid` prints a keypair)
VAPID_PUBLIC_KEY=
VAPID_PRIVATE_KEY=
VAPID_SUBJECT=mailto:admin@sawaari.local

# Maps/routing (defaults are free public instances; self-host for production)
OSRM_BASE_URL=https://router.project-osrm.org
# Extra routing hosts tried in order if the primary is unreachable
OSRM_FALLBACK_URLS=https://routing.openstreetmap.de/routed-car
NOMINATIM_BASE_URL=https://nominatim.openstreetmap.org

UPLOAD_DIR=uploads
```

### What happens when a service is unconfigured

| Service   | Unconfigured / unreachable behaviour |
|-----------|------------------------------------|
| Razorpay  | Online payments hidden; UPI QR / UPI intent / cash still fully work |
| SMS       | `SMS_DEV_MODE=true` shows OTP in server log + API response |
| Web Push  | Real-time in-app (socket) notifications still work |
| Email     | Disabled; everything important also appears in-app |
| OSRM routing | Hosts are tried in order (`OSRM_BASE_URL` → `OSRM_FALLBACK_URLS`); if all fail the fare falls back to a straight-line estimate and the UI says *"Live road routing is unreachable right now"* |

`GET /api/health` always reports the true state of each integration.

---

## 🐳 Docker (optional)

```bash
docker compose up -d        # starts PostgreSQL 17 on :5432 (sawaari/sawaari)
```

Then point `DATABASE_URL` in `server/.env` at `postgres://sawaari:sawaari@localhost:5432/sawaari` and run `npm run setup` inside `server/`. The app itself runs directly on Node (no container needed); only the database is containerized for convenience.

---

## 🧪 Testing the full workflow

Five suites cover the platform end to end:

```bash
cd server

# Rider + driver + admin journey (61 checks, 14 sections)
node src/scripts/e2e-test.js

# Super Admin console: sign-in, 2FA, RBAC, audit trail, owner protection, role isolation (64 checks)
node src/scripts/test-admin-api.js

# Every admin console endpoint + CSV export (43 checks)
node src/scripts/sweep-admin-api.js

# Frontend integrity: imports resolve, routes match, no dead components
node src/scripts/sweep-frontend.js

# Database: migrations, foreign keys, orphans, data integrity
node src/scripts/db-integrity.js
```

`e2e-test.js` exercises: passenger + driver registration with OTP, driver document submission, admin approval, driver online + GPS, nearby-driver search, OSRM fare quote, booking, driver accept (double-booking guard), ride progression with passenger OTP, UPI QR + UTR submission, admin payment verification, reviews, dashboards, cancellation policy, and security (role guards / blocked users / JWT checks).

`test-admin-api.js` exercises: password + TOTP sign-in, wrong-password lockout, the master dashboard, admin management, the audit log, platform settings, revenue/settlements, refunds, live rides, user lifecycle (block → suspend → deactivate → restore, with records retained), report investigation, permission enforcement, **role isolation** (a Finance Admin can set commission but cannot block users, list admins, change branding or touch gateway credentials), owner protection (cannot be suspended / deactivated / downgraded) and session revocation.

> The admin suites sign in as the seeded owner, so run `npm run seed:superadmin` first. Administrator sign-ins are rate limited per source address (`ADMIN_LOGIN_RATE_LIMIT`, default 20 per 15 minutes) — that is a real security control. If a run reports "sign-in throttled", wait 15 minutes, restart the API (the limiter lives in the process) or raise the limits in `server/.env` for a test environment.

### Manual walkthrough (UI)

1. Open `http://localhost:5173` → register a **driver** (any phone). OTP appears in the server console.
2. Sign in at `/admin-login` as the Super Admin → **Users** → the driver → **Suspend** (or **Block**) with a reason → the driver can no longer sign in or accept rides.
3. Log in as admin → **Driver Verification** → review documents → **Approve**.
4. Driver app → complete profile (vehicle, UPI) → toggle **Online** → allow location sharing (if GPS is unavailable, use **Set on map**).
5. Register a **passenger** → book a ride from the map → watch it assign → driver card shows accept/skip.
6. Driver accepts → *Arriving → Arrived*. Passenger sees the **ride OTP**.
7. Driver enters the OTP → **Start ride** → live tracking on the passenger map + public share link.
8. Driver completes the ride → passenger pays via the **UPI QR** and submits the UTR.
9. Admin → **Payments** → verify the UTR → payment becomes *paid*. **Revenue & Earnings** shows the commission split.
10. Passenger rates the driver. Try SOS, report user, support ticket, and the Admin Management / Audit Logs / Security screens.

---

## 📁 Project structure

```
transport/
├── docker-compose.yml        # PostgreSQL 17 (dev convenience)
├── server/                   # Node + Express API
│   ├── src/
│   │   ├── index.js          # bootstrap, Socket.IO, static uploads
│   │   ├── config.js         # env parsing (all .env vars live here)
│   │   ├── db.js             # pg pool helpers
│   │   ├── migrate.js         # applies src/migrations/*.sql in order
│   │   ├── seed.js           # admin, cities, pricing, settings
│   │   ├── middleware/       # auth (JWT), roles, rate limits, errors
│   │   ├── routes/           # auth, bookings, drivers, payments,
│   │   │                     # rides, support, cities, admin, webhooks
│   │   ├── services/         # rides engine, fares, OSRM, Nominatim,
│   │   │                     # razorpay, sms, email, push, notify
│   │   ├── scripts/          # e2e-test.js, generate-vapid.js
│   │   └── migrations/       # 001_init.sql (+ optional PostGIS)
│   └── uploads/              # avatars / documents / vehicles (gitignored)
└── web/                      # React SPA
    └── src/
        ├── api.js            # fetch wrapper + formatters
        ├── App.jsx           # routes per role
        ├── components/       # MapView, DashboardLayout, Modal, ...
        ├── context/          # Auth / Socket / Toast / Theme
        └── pages/            # auth/, passenger/, driver/, admin/, public
```

---

## 🔒 Security notes

- OTPs are stored **hashed** (SHA-256 + pepper), expire in 10 minutes, and are single-use
- Passwords hashed with bcrypt; JWTs signed with `JWT_SECRET`; role checked per route
- Razorpay payments verified by **HMAC signature** (checkout) and **webhook secret** (server-to-server)
- UPI payments require the passenger's UTR and remain `awaiting_verification` until an admin confirms — the client can never mark itself paid
- Uploads restricted by type/size; all input validated with zod
- Change `JWT_SECRET`, `OTP_PEPPER`, and `ADMIN_PASSWORD` before deploying. `SMS_DEV_MODE` must be `false` in production.

## 🗺️ Production considerations

- Self-host OSRM (India extract) + Nominatim for map/routing reliability and rate limits. Public OSRM mirrors are rate-limited and occasionally unreachable — the platform degrades to a labelled distance estimate rather than failing, but a self-hosted instance is the real fix.
- Terminate HTTPS at a reverse proxy (nginx/caddy) in front of both apps
- Run `NODE_ENV=production`, set `APP_URL` to the public origin (used in share links)
- Configure Razorpay webhooks to a public URL; keep the webhook secret in sync
- Back up PostgreSQL; the schema is plain SQL in `server/src/migrations/`
- The driver's browser geolocation needs permission; the "Set on map" fallback keeps the platform usable when it is denied
