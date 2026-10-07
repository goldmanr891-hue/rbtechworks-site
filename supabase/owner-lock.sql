-- Lock dashboard data to the owner's account (support@rbtechworks.com) instead of "any signed-in user".
-- Step 1 (run now): owner account only.
do $$
declare owner uuid;
begin
  select id into owner from auth.users where email = 'support@rbtechworks.com';
  if owner is null then raise exception 'owner account not found'; end if;

  execute 'drop policy if exists "owner manages services" on public.services';
  execute format('create policy "owner manages services" on public.services for all to authenticated using (auth.uid() = %L::uuid) with check (auth.uid() = %L::uuid)', owner, owner);

  execute 'drop policy if exists "owner manages events" on public.service_events';
  execute format('create policy "owner manages events" on public.service_events for all to authenticated using (auth.uid() = %L::uuid) with check (auth.uid() = %L::uuid)', owner, owner);
end $$;

-- Step 2 (run only AFTER two-factor is set up and the MFA dashboard is live):
-- also require a two-factor session (aal2) to read or change anything.
-- do $$
-- declare owner uuid;
-- begin
--   select id into owner from auth.users where email = 'support@rbtechworks.com';
--   execute 'drop policy if exists "owner manages services" on public.services';
--   execute format('create policy "owner manages services" on public.services for all to authenticated using (auth.uid() = %L::uuid and (auth.jwt() ->> ''aal'') = ''aal2'') with check (auth.uid() = %L::uuid and (auth.jwt() ->> ''aal'') = ''aal2'')', owner, owner);
--   execute 'drop policy if exists "owner manages events" on public.service_events';
--   execute format('create policy "owner manages events" on public.service_events for all to authenticated using (auth.uid() = %L::uuid and (auth.jwt() ->> ''aal'') = ''aal2'') with check (auth.uid() = %L::uuid and (auth.jwt() ->> ''aal'') = ''aal2'')', owner, owner);
-- end $$;
