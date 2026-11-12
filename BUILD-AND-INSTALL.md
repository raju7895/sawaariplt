# Building & installing Sawaari on Android, Windows and the web

Everything below runs against the **same API and the same PostgreSQL database** as the
existing web app — the installed apps are shells around the identical front-end.

```
┌──────────────┐   ┌───────────────┐   ┌──────────────┐
│ Android APK  │   │ Windows app   │   │  PWA / web   │
└──────┬───────┘   └───────┬───────┘   └──────┬───────┘
       │  https/http://host:4000             │
       └───────────────┬──────────────────────┘
                       ▼
              Express API + Socket.IO
                       ▼
              PostgreSQL (sawaari)
```

---

## 0. One-time toolchain setup

```powershell
node scripts/setup-android-toolchain.js     # JDK 17 + Android SDK (into .toolchain\)
node scripts/install-android-sdk.js         # accept licences + platform/build-tools
```

Nothing is installed system-wide; everything lands in `.toolchain\` (git-ignored).
Requires ~2 GB of disk and a working internet connection.

---

## 1. Android APK

### Build

```powershell
cd web
$env:VITE_API_URL="http://YOUR-SERVER-IP:4000"   # baked-in default; changeable in-app
npm run build                                  # production web build
npx cap sync android                           # copy the build into the project
node scripts/setup-android-signing.cjs          # create/reuse the release keystore

cd android
.\gradlew.bat assembleRelease --no-daemon
```

**Output:** `web\android\app\build\outputs\apk\release\app-release.apk`

### Signing

`scripts/setup-android-signing.cjs` creates `android\sawaari-release.keystore` (RSA
2048, SHA-256, valid 30 years) and writes the credentials to
`android\keystore.properties`. **Both are git-ignored**, and a copy is kept in
`server\backups\`. Back them up — without the keystore you cannot publish updates
to the same app listing.

Verify a build:

```powershell
& "$env:ANDROID_HOME\build-tools\34.0.0\apksigner.bat" verify --print-certs `
   app\build\outputs\apk\release\app-release.apk
```

### Installing on a phone

1. Copy the APK to the phone (USB, Drive, email) and open it.
2. Allow **"install from unknown sources"** for the app you open it with.
3. Launch **Sawaari**.
4. On the login screen tap **Server settings** and enter your server address,
   e.g. `http://192.168.1.5:4000` (your PC's LAN address — run `ipconfig` to find
   it). Tap **Test connection**, then **Save & reload**.

### What the app asks for

| Permission | Why |
|---|---|
| Internet, network state | talks to your API |
| Location (fine/coarse) | driver GPS, pickup/drop map, "nearby autos" |
| Camera, media | vehicle photos and document uploads |
| Notifications (Android 13+) | ride requests, ride updates |

`usesCleartextTraffic` is enabled so a plain-HTTP LAN server works out of the box.
Put the API behind HTTPS for anything beyond a home network.

---

## 2. Windows desktop app (Electron)

```powershell
cd web
$env:VITE_API_URL="http://localhost:4000"
npm run build                                  # the app is served from disk

cd ..\electron
npm install                                    # once
node build-icon.cjs                            # generates build\icon.ico
npx electron-builder --win --x64 --dir         # packages dist\win-unpacked
```

Then build the installers with NSIS (already present in the electron-builder cache):

```powershell
$makensis = "$env:LOCALAPPDATA\electron-builder\Cache\nsis\nsis-3.0.4.1\Bin\makensis.exe"
& $makensis /V3 installer.nsi                  # → dist-windows\LocalAutoBooking-Setup.exe
& $makensis /V3 portable.nsi                   # → dist-windows\LocalAutoBooking-Portable.exe
```

**Output:**

| File | What it is |
|---|---|
| `dist-windows\LocalAutoBooking-Setup.exe` | Installer (per-user, no admin rights, desktop + start-menu shortcuts, uninstaller) |
| `dist-windows\LocalAutoBooking-Portable.exe` | Runs from a temporary folder, installs nothing |
| `electron\dist\win-unpacked\` | The unpacked application folder |

The desktop app serves the web build from `http://127.0.0.1:5188` (a fixed port so
the saved session survives restarts) and talks to the API through the same
runtime-configurable address as the mobile app — **Server settings** on the home
screen or the login page.

> **Code signing:** the Windows binaries are produced unsigned. A machine with
> *Windows Defender Smart App Control* or a strict WDAC/App Control policy blocks
> unsigned executables (including this one) — sign them with a code-signing
> certificate to run there, or use the PWA, which needs no local executable.

---

## 3. Installable PWA (Chrome / Edge)

The PWA is already part of the web build:

* `web/public/manifest.webmanifest` — name, icons (incl. maskable), shortcuts
* `web/public/sw.js` — offline shell, network-first API, cached map tiles
* `web/public/icons/*` — generated launcher icons
* `web/src/components/InstallPrompt.jsx` — the in-app install button
* `web/src/components/ServerSettings.jsx` — runtime API address

**Install:** Chrome/Edge → open the site → the install prompt appears (or use the
⋮ menu → *Install Sawaari* / *Apps → Install this site as an app*).
It then launches standalone with its own icon, works offline for the app shell and
keeps your session.

---

## 4. Runtime server address

Every build (APK, desktop, PWA) resolves the API in this order:

1. an address saved in **Server settings** (persisted on the device),
2. `VITE_API_URL` baked in at build time,
3. the same origin the app was opened from.

That is what makes one APK work against a laptop on the LAN today and a hosted
API tomorrow — no rebuild required.

---

## 5. Everything at a glance

| Deliverable | File | Notes |
|---|---|---|
| Android APK | `dist-android/LocalAutoBooking.apk` | Signed release build |
| Windows installer | `dist-windows/LocalAutoBooking-Setup.exe` | Unsigned (see note) |
| Windows portable | `dist-windows/LocalAutoBooking-Portable.exe` | Unsigned (see note) |
| PWA | served from `web/dist` | Install from Chrome/Edge |
| Unpacked desktop app | `electron/dist/win-unpacked/` | Runs without an installer |
| Source | the whole repository | `README.md` + this file |

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| "Cannot reach the Sawaari server" | Wrong server address → Server settings → Test connection |
| APK will not install | "Unknown sources" not allowed for that app; or the APK was transferred as `.apk.txt` |
| Blank screen in the APK | The web build was not synced: `npm run build && npx cap sync android` |
| Gradle: SDK location not found | `ANDROID_HOME` must point at `.toolchain\android-sdk` |
| Gradle: `keystore.properties` missing | Run `node scripts/setup-android-signing.cjs` |
| Desktop app: port 5188 busy | Close the other copy; the port is fixed so sessions persist |
| Windows blocks the installer | App Control / Smart App Control blocks unsigned binaries — use the PWA or sign the binary |
| Map tiles missing | The device needs internet access for CARTO/OSM tiles |
