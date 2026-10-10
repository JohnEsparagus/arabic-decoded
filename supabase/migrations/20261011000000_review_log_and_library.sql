-- The rest of what a user builds up besides card progress, so it follows
-- them to a new device too: their review history (what the learning stats
-- and the streak are drawn from) and their library (favorites and
-- collections). Pushed and pulled by `lib/services/sync_service.dart`.
--
-- As in card_progress, a card is identified by (deck_name, arabic_word):
-- each device's local SQLite assigns its own ids.

-- One row per change to a card's progress. Append-only: rows are never
-- updated or deleted, so there are no conflicts to settle, only duplicates
-- to ignore (the unique constraint) when two devices upload the same one.
create table public.review_log (
  -- Assigned by the server in arrival order. Devices remember the highest
  -- id they've fetched and ask only for rows after it.
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  deck_name text not null,
  arabic_word text not null,
  reviewed_at timestamptz not null,
  -- The card's interval from this moment on, and whether this left it
  -- never-studied (a reset).
  interval_days integer not null,
  is_new boolean not null default false,
  -- True for a card graded in a study session; false for marking it
  -- mastered by hand, a reset, or an estimate of history from before the
  -- log existed. Only graded rows count as reviews and toward a streak.
  graded boolean not null default false,
  unique (user_id, deck_name, arabic_word, reviewed_at)
);

create index review_log_user_id_id on public.review_log (user_id, id);

alter table public.review_log enable row level security;

grant select, insert on public.review_log to authenticated;

create policy "Users read their own review log"
  on public.review_log for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users add to their own review log"
  on public.review_log for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- A user's favorites and collections, as one JSON document per user (its
-- shape is documented on LibrarySnapshot in lib/models/synced_extras.dart).
-- It's small, and it's always read and written whole, so one row is
-- simpler than a table per kind of thing with deletions to track. The
-- cost: if two devices change it while both are offline, the one that
-- changed it last wins outright.
create table public.user_library (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  data jsonb not null,
  -- When the library was last changed, by the changing device's clock.
  updated_at timestamptz not null
);

alter table public.user_library enable row level security;

grant select, insert, update on public.user_library to authenticated;

create policy "Users read their own library"
  on public.user_library for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert their own library"
  on public.user_library for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update their own library"
  on public.user_library for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Same rule as card_progress: an upload older than what's stored is
-- dropped, so a device that was offline can't overwrite a newer library.
create function public.user_library_keep_newest()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at < old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

create trigger user_library_keep_newest
  before update on public.user_library
  for each row execute function public.user_library_keep_newest();
