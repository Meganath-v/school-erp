-- Locks the public schema against Supabase Data API access (anon/authenticated).
-- The NestJS backend connects as postgres (BYPASSRLS), so it is unaffected.
-- Re-run after `prisma db push` adds new tables.
begin;
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on tables    from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
commit;
