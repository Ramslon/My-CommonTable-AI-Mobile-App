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
