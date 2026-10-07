-- RB Tech Works services dashboard: schema, security and history triggers.
-- Run once in the Supabase SQL editor. Safe to re-run (drops and recreates policies/triggers).

-- ── Tables ────────────────────────────────────────────────────────────────
create table if not exists public.services (
  id            bigint generated always as identity (start with 1001) primary key,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  name          text not null check (char_length(name) between 1 and 120),
  phone         text check (char_length(phone) <= 40),
  email         text check (char_length(email) <= 200),
  service_type  text check (char_length(service_type) <= 80),
  device        text check (char_length(device) <= 200),
  issue         text check (char_length(issue) <= 4000),
  quote         numeric(10,2),
  parts         text check (char_length(parts) <= 500),
  status        text not null default 'New'
                check (status in ('New','Quoted','Approved','In progress','Ready for pickup','Paid','Closed')),
  source        text not null default 'Website'
                check (source in ('Website','Call','Text','Walk-in','Email','Facebook')),
  notify        boolean not null default false  -- owner-created services: send the confirmation email
);
alter table public.services add column if not exists notify boolean not null default false;

create table if not exists public.service_events (
  id          bigint generated always as identity primary key,
  service_id  bigint not null references public.services(id) on delete cascade,
  created_at  timestamptz not null default now(),
  kind        text not null check (kind in ('created','status','note','email')),
  message     text not null check (char_length(message) <= 4000)
);
create index if not exists service_events_service_id_idx on public.service_events(service_id, created_at);
create index if not exists services_status_idx on public.services(status, created_at desc);

alter table public.services       enable row level security;
alter table public.service_events enable row level security;

-- ── Privileges (new tables are not exposed automatically in this project) ──
-- Website visitors (anon) may only INSERT a new request, limited to these columns.
revoke all on public.services, public.service_events from anon, authenticated;
grant insert (name, phone, email, service_type, device, issue) on public.services to anon;
-- The signed-in owner (authenticated) manages everything.
grant select, insert, update, delete on public.services, public.service_events to authenticated;
-- The confirmation-email edge function reads and logs with the service role.
grant select, insert, update, delete on public.services, public.service_events to service_role;
grant usage, select on all sequences in schema public to service_role;

-- ── Row level security policies ─────────────────────────────────────────────
drop policy if exists "website can submit requests" on public.services;
create policy "website can submit requests" on public.services
  for insert to anon
  with check (status = 'New' and source = 'Website' and quote is null);

drop policy if exists "owner manages services" on public.services;
create policy "owner manages services" on public.services
  for all to authenticated using (true) with check (true);

drop policy if exists "owner manages events" on public.service_events;
create policy "owner manages events" on public.service_events
  for all to authenticated using (true) with check (true);

-- ── History: log creation and every status change automatically ───────────
create or replace function public.log_service_created() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.service_events(service_id, kind, message)
  values (new.id, 'created', 'Created from ' || new.source);
  return new;
end $$;

create or replace function public.log_service_updated() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  if new.status is distinct from old.status then
    insert into public.service_events(service_id, kind, message)
    values (new.id, 'status', 'Status: ' || old.status || ' → ' || new.status);
  end if;
  return new;
end $$;

drop trigger if exists services_created on public.services;
create trigger services_created after insert on public.services
  for each row execute function public.log_service_created();

drop trigger if exists services_updated on public.services;
create trigger services_updated before update on public.services
  for each row execute function public.log_service_updated();

revoke execute on function public.log_service_created(), public.log_service_updated() from public, anon, authenticated;
