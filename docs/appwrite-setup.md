# Appwrite migration

Appwrite has been replaced by SQLite + Supabase. Follow
[Supabase setup](supabase-setup.md).

Existing SQLite data and pending queue entries are preserved. The first
authenticated Supabase sync queues all existing local records, including rows
previously uploaded to Appwrite. Old Appwrite pull cursors are not reused.

Records present only in Appwrite are not imported automatically. Before
switching, synchronize the old app to bring those records onto the source
device and back up its SQLite database. Stop using Appwrite-backed app versions
after migration; they do not exchange changes with Supabase.

The old `APPWRITE_*` build settings are no longer used. Do not copy privileged
Appwrite keys or Supabase secret/service-role keys into the app.
