# CommonTable AI Mobile App

Student-first wellness and nutrition companion built with Flutter. It blends meal planning, community features, and a privacy-respecting AI coach powered by Gemini, OpenAI, or Hugging Face.

## Key features

- Student wellness: meal guidance, budget ideas, mood support, and quick tips
- Premium Wellness Chat: safe, concise AI coaching with provider fallbacks
- Community: posts, likes, comments, challenges (rules secured in Firestore)
- Offline resilience: caching, timeouts, simulated AI when needed
- Diagnostics screen: quick health checks for AI providers and Supabase

## Tech stack

- Flutter/Dart (Android, iOS, Web, Desktop)
- Firebase: Auth, Firestore, Realtime Database, Messaging, Storage
- AI providers: Google Gemini, OpenAI, Hugging Face (HF Router)
- Optional: Supabase (recipes), Fitbit OAuth template

## Prerequisites

- Flutter SDK (latest stable)
- Dart (bundled with Flutter)
- Firebase CLI and FlutterFire CLI
- A Firebase project (see `lib/firebase_options.dart` is already configured)

## Quick start

1) Install dependencies

```bash
flutter pub get
```

2) Environment variables

Create a `.env` at the repository root. Example:

```ini
# AI Providers (set any you plan to use)
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.0-flash

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini

HF_API_KEY=
HF_API_BASE=https://router.huggingface.co/hf-inference
HF_MODEL=facebook/bart-large-cnn
HF_FALLBACK_MODEL=sshleifer/distilbart-cnn-12-6

# Optional integrations
SUPABASE_URL=
SUPABASE_ANON_KEY=
CALORIE_NINJAS_KEY=

# Feature flags
USE_OFFLINE_AI=false
```

Notes:
- Do not commit real keys. Keep `.env` locally or in secure secrets.
- The app reads `.env` first then `--dart-define` values.

3) Firebase: Firestore rules and indexes

Rules and indexes are wired in `firebase.json`.

```bash
firebase login
firebase use --add        # pick your project (e.g., commonai-app)
firebase deploy --only firestore
```

4) Firebase: Realtime Database rules

First, create a Realtime Database instance in the Console (recommended region: us-central1). Then deploy the rules defined in `database.rules.json`:

```bash
firebase deploy --only database
```

By default, the rules allow public read of `local_offers/global` only. To require auth, change that path to `".read": "auth != null"` and redeploy.

5) Android biometrics

- `MainActivity` extends `FlutterFragmentActivity` to support `local_auth`.
- Manifest includes biometric permissions. If you still can’t authenticate, check enrollment on the device.

6) Run the app

```bash
flutter run
```

7) Run tests

```bash
flutter test
```

## Configuration notes

- AI provider selection is automatic based on available keys, with fallbacks. HF calls use the Router endpoint and set `wait_for_model`/`use_cache` by default.
- Diagnostics screen (Settings → Diagnostics) checks Gemini, OpenAI, HF, and Supabase.
- Offline mode forces simulated AI responses.

## Troubleshooting

### Hugging Face 410 or HTML errors

- Use the Router base: `HF_API_BASE=https://router.huggingface.co/hf-inference`
- Ensure a valid `HF_MODEL` and consider `HF_FALLBACK_MODEL`.
- For PowerShell testing, use `curl.exe` and include `Connection: close`, or use `Invoke-RestMethod`.

### RTDB forced disconnect / permission denied

- Confirm your Realtime Database instance exists (Console → Realtime Database → Create Database).
- Ensure `lib/firebase_options.dart` points at your project’s `databaseURL`.
- Deploy `database.rules.json` and verify access to `local_offers/global`.

### Firestore PERMISSION_DENIED on subscriptions

- Subscriptions rules allow reads/writes by doc owner or by `resource.data.userId`.
- Code writes include `userId` into `subscriptions/{uid}`. Old docs without `userId` may fail queries; re-save them.

### Android biometrics error (needs FragmentActivity)

- Fixed by extending `FlutterFragmentActivity` and adding permissions.
- The UI now handles missing hardware/enrollment and common `PlatformException`s.

### Firebase CLI auth vs service accounts

- Interactive: `firebase login` is simplest.
- Non-interactive: set `GOOGLE_APPLICATION_CREDENTIALS` to a service account JSON from the same Firebase project and run deploys with `--project <id>`.

## Development plan (high-level)

Done
- Firestore: updated rules (users, preferences, subscriptions with `userId`, consents immutable) and deployed indexes
- Community: basic rules for posts/comments/likes/challenges; gating on Firebase init
- Billing/subscriptions: normalized writes with `userId`, deletion path covered
- HF integration: Router base, fallback model, `wait_for_model`/`use_cache`, HTML error sanitization, provider fallbacks
- Android: biometric compatibility (FragmentActivity) and UI hardening
- RTDB: rules file and wiring; global offers path documented
- Analyzer & tests pass

Next
- Verify runtime queries after index builds (chat history, diet assessments, mood logs)
- Optionally switch RTDB `local_offers/global` to auth-only and seed environment data
- Expand test coverage for privacy flows (export/delete) and community actions
- CI: add GitHub Actions for analyze/test and optional Firebase deploy

## Optional integrations

### Supabase (recipes)

This app can personalize meal plans using recipe data from a Supabase table.

1. Create a Supabase project and add a `recipes` table with columns:
   - `name` (text), `calories` (int), `protein` (int), `carbs` (int), `fats` (int)
2. Set env vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
3. Run the app; the generator merges Supabase items with the local food database

### Fitbit OAuth (template)

1. Create an app at https://dev.fitbit.com/apps and set redirect URI: `commontable.fitbit://auth/callback`
2. Env vars: `FITBIT_CLIENT_ID`, `FITBIT_REDIRECT_URI` (and optionally `FITBIT_CLIENT_SECRET` if using a backend)
3. Android manifest placeholders and iOS Info.plist are pre-wired for the callback

## Contributing

Pull requests welcome. Please run `flutter analyze` and `flutter test` before submitting. For changes touching Firebase rules, include a short note and test steps.

## License

Proprietary — All rights reserved. Contact the repository owner for licensing options.
