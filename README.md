<!-- Badges -->
<p align="center">
   <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" alt="Flutter"></a>
   <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20RTDB-ffca28?logo=firebase&logoColor=white" alt="Firebase"></a>
   <a href="#tests"><img src="https://img.shields.io/badge/Tests-passing-brightgreen" alt="Tests"></a>
   <a href="#license"><img src="https://img.shields.io/badge/License-Private-lightgrey" alt="License"></a>
</p>

# CommonTable AI Mobile App

Student-first wellness and nutrition companion built with Flutter. It blends meal planning, community features, and a privacy-respecting AI coach powered by Gemini, OpenAI, or Hugging Face.

<!-- Screenshots (add your actual images when available) -->
<p align="center">
   <em>Screenshots coming soon (Home · Premium Chat · Community)</em>
</p>

## What the app does

- Provides budget-friendly meal guidance and mood-based nutrition tips for students
- Delivers a Premium Wellness Chat experience with safe, concise AI coaching
- Enables a community space for posts, likes, comments, and challenges
- Supports offline resilience and diagnostics for quick provider health checks

## Tech stack

- Flutter/Dart (Android, iOS, Web, Desktop)
- Firebase: Auth, Firestore, Realtime Database, Messaging, Storage
- AI providers: Google Gemini, OpenAI, Hugging Face (via HF Router)
- Optional: Supabase (recipes), Fitbit OAuth template

## Project structure

```
lib/
   core/              # Services (AI, payments, privacy, diagnostics, etc.)
   presentation/      # Screens & widgets (UI)
   routes/            # App routes
   firebase_options.dart
assets/
   data/              # Mock data / seeded content
   legal/             # Markdown legal documents
android/, ios/, web/, macos/, windows/, linux/  # Platform code
```

## Setup & run locally

<details>
<summary><strong>1) Prerequisites</strong></summary>

- Flutter SDK (latest stable)
- Firebase CLI and FlutterFire CLI
- A Firebase project (see `lib/firebase_options.dart`)

</details>

<details>
<summary><strong>2) Install dependencies</strong></summary>

```bash
flutter pub get
```

</details>

<details>
<summary><strong>3) Environment variables (.env)</strong></summary>

Create a `.env` in the repo root:

```ini
# AI Providers
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.0-flash

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

HF_API_KEY=
HF_API_BASE=https://router.huggingface.co/hf-inference
HF_MODEL=facebook/bart-large-cnn
HF_FALLBACK_MODEL=sshleifer/distilbart-cnn-12-6

# Optional
SUPABASE_URL=
SUPABASE_ANON_KEY=
CALORIE_NINJAS_KEY=

# Flags
USE_OFFLINE_AI=false
```

Notes: never commit real keys. The app reads `.env` first, then `--dart-define`.

</details>

<details>
<summary><strong>4) Firebase: Firestore & RTDB</strong></summary>

Firestore:
```bash
firebase login
firebase use --add        # pick your project (e.g., commonai-app)
firebase deploy --only firestore
```

Realtime Database:
1. In Firebase Console, create a Realtime Database (region: us-central1 recommended)
2. Deploy rules from `database.rules.json`:
```bash
firebase deploy --only database
```

By default, only `local_offers/global` is readable; change to `auth != null` if preferred.

</details>

<details>
<summary><strong>5) Android biometrics</strong></summary>

- `MainActivity` extends `FlutterFragmentActivity`
- Manifest contains biometric permissions
- The UI handles missing hardware/enrollment and `PlatformException`s

</details>

<details>
<summary><strong>6) Run & test</strong></summary>

```bash
flutter run
```

```bash
flutter test
```

</details>

## Connecting the APIs

- Gemini: set `GEMINI_API_KEY`, `GEMINI_MODEL`
- OpenAI: set `OPENAI_API_KEY`, `OPENAI_MODEL`
- Hugging Face: set `HF_API_KEY`, `HF_API_BASE` (router), `HF_MODEL`, optional `HF_FALLBACK_MODEL`
- Supabase: set `SUPABASE_URL`, `SUPABASE_ANON_KEY`

Provider selection is automatic; the app falls back across providers and ultimately to a simulated response for offline mode.

## Build (APK / AAB)

Android APK (unsigned debug):
```bash
flutter build apk --debug
```

Android APK (release):
```bash
flutter build apk --release
```

Android App Bundle (AAB):
```bash
flutter build appbundle --release
```

Signing: configure a keystore and update `android/key.properties` and Gradle signing configs per Flutter docs.

## Testing the APIs (from PowerShell on Windows)

Hugging Face (Router) with `curl.exe`:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
curl.exe -s -X POST "https://router.huggingface.co/hf-inference/models/facebook/bart-large-cnn" `
   -H "Authorization: Bearer $env:HF_API_KEY" `
   -H "Content-Type: application/json" `
   -H "Connection: close" `
   --data "{\"inputs\":\"The quick brown fox...\",\"options\":{\"wait_for_model\":true,\"use_cache\":true}}"
```

OpenAI:
```powershell
Invoke-RestMethod -Method POST -Uri "https://api.openai.com/v1/chat/completions" `
   -Headers @{Authorization="Bearer $env:OPENAI_API_KEY";"Content-Type"="application/json"} `
   -Body '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"ping"}],"max_tokens":4}'
```

Gemini:
```powershell
Invoke-RestMethod -Method POST -Uri "https://generativelanguage.googleapis.com/v1beta/models/$env:GEMINI_MODEL:generateContent?key=$env:GEMINI_API_KEY" `
   -Headers @{"Content-Type"="application/json"} `
   -Body '{"contents":[{"role":"user","parts":[{"text":"ping"}]}]}'
```

## Troubleshooting

Hugging Face 410/HTML:
- Use Router base; set `wait_for_model` and `use_cache`; prefer `curl.exe` on Windows

RTDB disconnect/permission:
- Create the DB instance; deploy `database.rules.json`; verify `databaseURL` in `firebase_options.dart`

Subscriptions PERMISSION_DENIED:
- Rules allow owner or `resource.data.userId`; code writes include `userId` to `subscriptions/{uid}`

Android biometrics:
- FragmentActivity + permissions + UI guards for missing/enrolled hardware

Firebase auth (CLI vs SA):
- Interactive `firebase login` or service account via `GOOGLE_APPLICATION_CREDENTIALS`

## Challenges & Mitigation

- HF 410 and HTML error bodies → switched to Router, added fallback model, sanitized errors, and provider fallbacks
- Firestore subscription access issues → rules accept doc owner or `userId`; code writes `userId`
- Android LocalAuth crash → `FlutterFragmentActivity` + exception handling and support/enrollment checks
- RTDB forced disconnects → added rules file and docs to create DB instance and deploy rules

## Development plan

Done:
- Firestore rules/indexes; community gating; subscriptions normalization and deletion; HF Router + fallbacks; biometrics hardening; RTDB rules; analyzer/tests pass

Next:
- Verify post-index runtime; optionally tighten RTDB reads; expand tests; add CI for analyze/test and optional deploy

## Contributing

Pull requests welcome. Run `flutter analyze` and `flutter test` before submitting. For Firebase rules changes, include a test plan.

### Contributors

- Ramson Lunayo — Lead Developer — <ramsonlonayo@gmail.com>

## License

Proprietary — All rights reserved. Contact the repository owner for licensing options.
