# Outloud — Single-App App Store Submission Flow

> Tailored playbook for shipping **Outloud** through the same pipeline you use
> for the exam apps (`~/.claude/skills/ios-store-pipeline/`). Run this from your
> **Mac / macOS CI** where Xcode + your ASC API key live — the binary build
> (`.ipa`) cannot be produced on Linux, so the remote web sandbox can prep
> everything *except* the build + upload.
>
> Every Outloud-specific value (bundle ids, product ids, price, copy, privacy
> URL) is filled in below so `asc.py` just consumes it.

## 0. Credentials & prerequisites (one-time, on your machine)

| Need | Value / where |
|---|---|
| App Store Connect API key | your `AuthKey_XXXX.p8` + Issuer ID + Key ID (already wired into `asc.py`) |
| Team ID | `REPLACE_WITH_TEAM_ID` → set in `project.yml` + `Outloud.storekit` |
| Xcode | 16+ (iOS 18 SDK) — required for `build_app` |
| Org | Fly Sky Pty Ltd |

```bash
cd outloud-app
xcodegen generate          # project.yml → Outloud.xcodeproj
```

---

## Step 1 — Bundle IDs & capabilities (`asc.py` → register bundle id)

Register **two** identifiers (host + share extension) and enable the same
capabilities the code assumes:

| Bundle ID | Role | Capabilities |
|---|---|---|
| `au.com.flysky.outloud` | host app | App Groups, Background Modes (Audio) |
| `au.com.flysky.outloud.ShareExtension` | share extension | App Groups |

- App Group: **`group.au.com.flysky.outloud`** (must match both `.entitlements`).
- This maps to your skill's *create-bid* step — register both, not just one.

## Step 2 — Create the app record (`asc.py` → create app)

| Field | Value |
|---|---|
| Name | **Outloud** |
| Primary language | English (U.S.) |
| Bundle ID | `au.com.flysky.outloud` |
| SKU | `OUTLOUD-001` |
| Primary category | Productivity |
| Secondary category | Utilities |

## Step 3 — ASO / metadata (`finalize_app`)

Positioning to lead with: **on-device · offline · pay-once** (NOT voices).

- **Title (≤30):** `Outloud: Listen to Documents`
- **Subtitle (≤30):** `On-device PDF read-aloud`
- **Keywords (≤100):** `text to speech,tts,pdf reader,read aloud,listen,voice,offline,document,article,audio,study`
- **Promotional text (≤170):** `Share any PDF or web page and Outloud reads it aloud in a natural voice — 100% on your device. No account, no upload, works offline. Pay once.`
- **Description:** see `metadata/description.txt` (drafted below).
- **Support URL:** `https://ycymycym.github.io/docs/outloud/` (confirm Pages domain)
- **Marketing URL:** same page.

## Step 4 — Screenshots (`capture_shots` → `upload_shots`)

Required display sizes (one set each): **6.9" iPhone**, **6.5" iPhone**,
**13" iPad**. Suggested 5 frames, in order:

1. Now-Playing screen mid-read — caption "Listen to any PDF."
2. Share sheet → Outloud — "Share from anywhere."
3. Library with resume — "Pick up where you left off."
4. Voice picker — "Natural on-device voices."
5. Paywall — "Pay once. No subscription, ever."

Run `capture_shots` against the Outloud scheme on the simulator set, then
`upload_shots`.

## Step 5 — In-App Purchases & subscription (`asc.py` → IAP)

Mirror `Products.swift` / `Outloud.storekit` exactly:

| Product ID | Type | Price | Notes |
|---|---|---|---|
| `au.com.flysky.outloud.lifetime` | Non-Consumable | **$39.99** | Primary CTA — "Pay once. No subscription, ever." |
| `au.com.flysky.outloud.monthly` | Auto-Renewable (group `Outloud Subscriptions`) | **$4.99/mo** | Anchor only |

- Add an IAP review screenshot of `PaywallView` + review notes:
  "Free tier caps at 5 min / 3000 chars; lifetime removes the cap. Restore tested."

## Step 6 — Privacy (`privacy_push`)

- **App Privacy nutrition label:** **Data Not Collected** (matches
  `PrivacyInfo.xcprivacy`). No tracking.
- **Privacy Policy URL:** `https://ycymycym.github.io/docs/outloud/`
  (the page already committed at `docs/outloud/index.html`).
- Note for reviewer: the only network call is a one-time on-device voice-model
  download from our CDN; no user data leaves the device.

## Step 7 — Build, upload, attach (`build_app` → `submit_app.py`)

```bash
# On macOS:
fastlane gym --scheme Outloud --export_method app-store   # or xcodebuild archive+export
# then your pipeline's upload (Transporter / altool / asc.py upload)
```

- Set version **1.0**, build **1** (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).
- Optional: push to **TestFlight** first for a smoke test of background audio +
  StoreKit sandbox.
- Attach the uploaded build to the 1.0 version.

## Step 8 — Submit for review → release (`submit_app.py` → verify → add to review → release)

1. Export-compliance: **No** non-exempt encryption (HTTPS only) →
   `ITSAppUsesNonExemptEncryption = false` (add to Info.plist to skip the prompt).
2. Content rights: you own/are licensed for the content (Kokoro = Apache-2.0,
   Readability = Apache-2.0, MisakiSwift = MIT — no GPL).
3. Age rating: 4+.
4. Add to review → submit → **release** (manual or automatic).

---

## Pipeline mapping (so it runs like the other 600 apps)

| Your skill tool | Outloud step here |
|---|---|
| `references/full-submission-flow.md` (8 steps) | Steps 1–8 above |
| `tools/submit/asc.py` | Steps 1, 2, 5 (bundle/app/IAP via ASC API) |
| `tools/submit/finalize_app.py` | Step 3 (metadata) |
| `tools/submit/capture_shots` + `upload_shots` | Step 4 (screenshots) |
| `tools/submit/privacy_push` | Step 6 (privacy label + policy URL) |
| `tools/submit/submit_app.py` | Steps 7–8 (finalize → verify → add to review → release) |

## What only you can do (the two real blockers from the web sandbox)

1. **Build the `.ipa`** — needs your Mac/Xcode once (no macOS here).
2. **Run `asc.py`/`submit_app.py`** — needs your `.p8` ASC key, which must stay
   on your machine (never paste it into a chat or commit it).

Everything else — source, StoreKit config, privacy page, this flow — is ready.
