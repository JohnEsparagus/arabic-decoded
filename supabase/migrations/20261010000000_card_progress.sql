-- Per-user spaced-repetition progress, one row per card a user has studied.
--
-- Card *content* (the roots, meanings, mnemonics) is not stored here — it
-- ships inside the app as JSON assets. This table only holds the SM-2
-- state that `lib/services/sync_service.dart` pushes and pulls.
--
-- Cards are identified by (deck_name, arabic_word) rather than a numeric
-- id, because each device's local SQLite assigns its own ids. Renaming a
-- deck in `lib/config/campaign_sources.dart` therefore orphans its rows
-- here unless they're renamed too.

create table public.card_progress (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  deck_name text not null,
  arabic_word text not null,
  ease_factor double precision not null,
  interval_days integer not null,
  repetitions integer not null,
  next_review timestamptz not null,
  introduced_at timestamptz,
  -- When the card was last graded, by the grading device's clock. Sync is
  -- last-write-wins on this column.
  updated_at timestamptz not null,
  primary key (user_id, deck_name, arabic_word)
);

alter table public.card_progress enable row level security;

grant select, insert, update on public.card_progress to authenticated;

create policy "Users read their own progress"
  on public.card_progress for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert their own progress"
  on public.card_progress for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update their own progress"
  on public.card_progress for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Two devices can push the same card. Silently drop an update that is
-- older than what's already stored, so a phone that was offline for a week
-- can't overwrite newer reviews made elsewhere.
create function public.card_progress_keep_newest()
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

create trigger card_progress_keep_newest
  before update on public.card_progress
  for each row execute function public.card_progress_keep_newest();
