# commontable_ai_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase integration (optional)

This app can personalize meal plans using recipe data from a Supabase table.

1. Create a Supabase project and add a `recipes` table with columns:
	- `name` (text)
	- `calories` (int)
	- `protein` (int)
	- `carbs` (int)
	- `fats` (int)
2. Set the following environment variables (either via `.env` at project root or `--dart-define`):
	- `SUPABASE_URL`
	- `SUPABASE_ANON_KEY`
3. Run the app. If configured, the generator will merge Supabase items with its local food database and filter by your saved allergies/dislikes.

Note: If Supabase is not configured, the app falls back to its built-in food database.

## Fitbit OAuth (template)

This app includes a template Fitbit OAuth2 (PKCE) integration wired into Health Sync Settings.

1) Create a Fitbit app at https://dev.fitbit.com/apps and set redirect URI:
	- Example: `commontable.fitbit://auth/callback`
2) Add environment variables (via `.env` at project root or `--dart-define`):
	- `FITBIT_CLIENT_ID=your_fitbit_client_id`
	- `FITBIT_REDIRECT_URI=commontable.fitbit://auth/callback`
	- Optional (discouraged on-device): `FITBIT_CLIENT_SECRET=...`
3) Android callback is pre-configured via manifest placeholders, and iOS Info.plist includes the matching URL scheme.
4) In the app: Settings → Health Sync Settings →
	- Connect Fitbit (OAuth)
	- View Fitbit profile
	- Disconnect

Notes:
- The included PKCE challenge is a minimal template. For production, replace it with a spec-compliant SHA-256 code challenge (e.g., using the `crypto` package) or move the exchange to a secure backend.
- Update scopes in `FitbitService` as needed.
- iOS deep-links whitelist (`LSApplicationQueriesSchemes`) is included for partner app opens.
