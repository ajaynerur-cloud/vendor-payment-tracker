create extension if not exists pgcrypto;
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vendor text not null check (char_length(vendor) between 1 and 120),
  payment_date date not null,
  mode text not null check (mode in ('Bank Transfer','UPI','Cheque','Cash','Card','Other')),
  purpose text not null check (char_length(purpose) between 1 and 240),
  amount numeric(14,2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists payments_user_date_idx on public.payments(user_id,payment_date desc);
alter table public.payments enable row level security;
drop policy if exists "Users read own payments" on public.payments;
drop policy if exists "Users insert own payments" on public.payments;
drop policy if exists "Users update own payments" on public.payments;
drop policy if exists "Users delete own payments" on public.payments;
create policy "Users read own payments" on public.payments for select using (auth.uid()=user_id);
create policy "Users insert own payments" on public.payments for insert with check (auth.uid()=user_id);
create policy "Users update own payments" on public.payments for update using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "Users delete own payments" on public.payments for delete using (auth.uid()=user_id);
create or replace function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
drop trigger if exists payments_updated_at on public.payments;
create trigger payments_updated_at before update on public.payments for each row execute function public.set_updated_at();
