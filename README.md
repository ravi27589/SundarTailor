# Sundar Tailor

Offline-first tailoring shop management app for Android phones and tablets.

## Phase 1 Scope

- Customer management
- Shirt, trouser, pajama, suit, shorts, kurta, safari, and additional measurements
- Order booking with multiple item rows, comments, quantities, delivery dates, status tracking, and printable measurement sheets
- Dashboard for deliveries and shop statistics
- SQLite local persistence
- SQLite-first Supabase sync with a persistent queue and private shop sign-in

## Local Setup

Flutter is required to build and run this project. After installing Flutter and adding it to `PATH`, run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

## Supabase Cloud Sync

Follow [Supabase setup](docs/supabase-setup.md) to create the free-tier database,
apply the SQL schema, and configure the app. SQLite works without cloud
configuration or sign-in. Web remains an in-memory preview without cloud sync.