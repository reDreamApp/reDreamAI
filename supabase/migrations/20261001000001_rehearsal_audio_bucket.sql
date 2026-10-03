-- Private Storage bucket for rehearsal audio (apps/ai writes it with the
-- service-role key; the app only gets signed URLs). Objects live under
-- users/{user_id}/{dream_id}/, which the GDPR purge in apps/api deletes.
--
-- Guarded: storage.buckets only exists where the Storage service has set up
-- its schema (self-hosted stack, `supabase start`), not on a bare Postgres.
do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values ('rehearsal-audio', 'rehearsal-audio', false)
    on conflict (id) do nothing;
  end if;
end
$$;
