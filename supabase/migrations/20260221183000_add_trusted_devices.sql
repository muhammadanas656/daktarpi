create extension if not exists pgcrypto;

create table if not exists public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  last_used_at timestamptz
);

create unique index if not exists trusted_devices_user_token_hash_idx
on public.trusted_devices (user_id, token_hash);

create index if not exists trusted_devices_user_expires_idx
on public.trusted_devices (user_id, expires_at desc);

alter table public.trusted_devices enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'trusted_devices'
      and policyname = 'Users manage own trusted devices'
  ) then
    create policy "Users manage own trusted devices"
      on public.trusted_devices
      for all
      to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end;
$$;
