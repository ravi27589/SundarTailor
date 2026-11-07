# SQLite + Supabase Free setup

SQLite remains the device's persistent database. Every local write is committed
with a sync queue entry. Supabase is an optional shared cloud copy, not a backup.
The Android app works offline without configuration or sign-in.

## 1. Create a free project

1. Create a Supabase Free project and keep its database password private.
2. In the SQL editor, run [schema.sql](../supabase/schema.sql) once on a new
   project. It creates customers, orders, device registrations, indexes, private
   read policies, and authenticated write RPCs. The script is transactional but
   is not designed to be rerun over an existing schema.
3. Under Authentication, disable public sign-ups. Create one shop user with an
   email/password using the dashboard's Add user action; confirm its email.
4. Sign in with that same account on every device belonging to this shop.
   Separate accounts intentionally cannot read each other's data.
5. Copy the project URL and **publishable key** from project settings. A legacy
   public `anon` key is also supported. Never use a secret key, service-role key,
   database password, or staff password in build settings.

## 2. Configure Flutter

```powershell
flutter pub get
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://idpizxmdyhsxkwsrhxrj.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_SiRaQGigx65CKpYxh892ww_2j4q4mJ5
```

Both settings are required, and the URL must use HTTPS. With missing/invalid
settings, cloud sync stays disabled. No cloud configuration is needed for local
SQLite use. The web preview still uses memory, not persistent SQLite, and does
not sync.

Open **Dashboard > Cloud sync settings**, enter the shop email/password, and
sign in. Credentials are entered at runtime, never compiled into the app.
The Supabase SDK persists the session using its Flutter storage integration.
Protect the device with an OS screen lock; local SQLite data is not encrypted.

The local database is bound to the first Supabase project/account used for sync.
Signing out retains local data and queued writes, and only the original shop
can resume syncing that database. Switching shops requires a separate app
installation/database, after backing up any existing data. The UI does not
provide a destructive reset.

## 3. Device numbering

The first successful connection registers the device with Supabase and saves a
unique **three-character** shop-scoped suffix, such as `001` or `0AZ`. New
customer/order numbers then look like `C000001-001` and `ORD-20261028-001-001`.
The server assigns suffixes, so they do not depend on collision-prone random
two/three-character IDs. Number allocation and local writes remain offline.

Connect each device once before using multiple devices to create records
offline. Numbers created before registration remain unchanged and unsuffixed.
Existing number conflicts between independent device databases are reported as
sync errors, never silently overwritten; reconcile those records before
migrating multiple previously independent databases. Start additional devices
with an empty database and sync the shop data first when possible.

## 4. Sync behavior

- Sync requires a configured project and a signed-in shop account.
- It runs on startup/session restoration, connectivity changes, manual
  **Sync now**, and every five minutes while the app is open. It is not an
  OS-level background service when the app is closed.
- The first sync queues existing local customers and orders that have no pending
  entry. This includes data previously synced to Appwrite.
- Customers upload before orders; writes for each entity remain ordered.
- Failed uploads remain queued with their error and retry automatically.
- Measurements convert between local JSON text and PostgreSQL JSONB.
- Deletes remain tombstones (`deleted_date`); no cloud hard-delete endpoint is
  exposed.
- Cloud writes use last-write-wins by UTC `updated_date`. An older upload cannot
  overwrite a newer cloud row. Equal timestamps accept the later upload.
  Keep device clocks accurate; simultaneous edits are not field-level merged.
- Cloud-assigned increasing `sync_version` values support paginated incremental
  pulls without relying on device clocks. The write RPCs serialize version
  allocation through commit. Do not bypass these RPCs for application writes.
- A pending local write prevents its remote row from replacing it. The pull
  cursor is retained when a row is skipped, so the cloud winner is reconsidered
  after queued uploads finish.
- Successful pulls refresh customer/order lists and dashboard providers.
- Cloud sync settings shows configuration, authentication and sync errors.

## Security

Customer/order reads require authentication and a matching `shop_id = auth.uid()`.
Anonymous reads and writes are denied. Authenticated clients cannot write
tables directly; the write RPCs derive shop ownership from the signed-in user
and apply timestamp conflict handling. Orders have a shop-scoped customer
foreign key and customer/order numbers are unique within each shop.

Use the provided schema only in a project you administer. Never expose
service-role credentials. Authentication protects cloud data, not physical
access to an unlocked device or its local SQLite database. A shared account
does not provide individual staff audit trails.

## Free-tier limits and backups

Supabase Free currently includes a 500 MB database and 5 GB ordinary egress,
with additional quotas for other products. Free projects pause after one week
of inactivity; resume a paused project in the Supabase dashboard. Local use
continues during cloud unavailability, and queued writes retry later.

Monitor usage in Supabase; free tier is not unlimited capacity or a production
availability guarantee. Review [current pricing](https://supabase.com/pricing)
before deployment. No paid functions or external offline-sync product are
required by this implementation.

Maintain independent SQLite/PostgreSQL exports. Free-tier sync does not include
a managed backup/restore guarantee. Do not clear app storage or uninstall an
app with unsynced data.

## Migrating from Appwrite

See [Appwrite migration](appwrite-setup.md). This change preserves the local
database and queue; it does not fetch records that exist only in Appwrite.
