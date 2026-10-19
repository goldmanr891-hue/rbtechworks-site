-- Adds the customer's preferred contact method (Call / Text / Email) to services.
-- Run once in the Supabase SQL editor BEFORE pushing the site change that sends it.
-- Additive only: does not touch the owner-only / 2FA policies from owner-lock.sql.
alter table public.services
  add column if not exists contact_pref text check (contact_pref in ('Call','Text','Email'));

-- Let the website form (anon, insert-only) fill in this one extra column.
grant insert (contact_pref) on public.services to anon;
