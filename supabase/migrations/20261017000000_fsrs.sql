-- The FSRS scheduler's per-card state (see lib/services/scheduler.dart),
-- synced alongside the rest of each card's progress. Nullable: rows from
-- before FSRS, or from an app version without it, simply don't have it,
-- and the app estimates it from interval_days and ease_factor instead.
alter table public.card_progress
  add column stability double precision,
  add column difficulty double precision;
