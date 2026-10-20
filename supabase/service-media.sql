-- Private storage bucket for drop-off / pickup photos and video, one folder per service id.
-- Run once in the Supabase SQL editor. Only the owner, signed in with 2FA (aal2), can view or add files.
-- No delete policy on purpose: evidence can't be removed from the dashboard (delete in Supabase if ever needed).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('service-media', 'service-media', false, 52428800, array['image/*', 'video/*'])
on conflict (id) do nothing;

drop policy if exists "owner reads service media" on storage.objects;
create policy "owner reads service media" on storage.objects for select to authenticated
  using (bucket_id = 'service-media' and auth.uid() = '00440be3-d12f-4453-ba0f-683bc5341c22'::uuid and (auth.jwt() ->> 'aal') = 'aal2');

drop policy if exists "owner adds service media" on storage.objects;
create policy "owner adds service media" on storage.objects for insert to authenticated
  with check (bucket_id = 'service-media' and auth.uid() = '00440be3-d12f-4453-ba0f-683bc5341c22'::uuid and (auth.jwt() ->> 'aal') = 'aal2');
