-- ============================================================
-- PCLX 配套网站 + 启动器 云端账号系统 · Supabase 初始化脚本
--
-- 使用方法：
--   1. 在 supabase.com 创建项目
--   2. 打开项目 → SQL Editor（SQL 编辑器）
--   3. 粘贴本文件全部内容并运行
--   4. 项目 Settings → API：复制 Project URL 与 anon public key
--      填入启动器「更多 → 云端账号 → 服务配置」
--   5. 如需邮箱注册，在 Authentication → Providers 启用 Email
--      （建议开启 "Confirm email" 以验证邮箱）
-- ============================================================

-- 用户资料表（auth.users 由 Supabase Auth 自动维护）
create table if not exists public.profiles (
  id uuid references auth.users (id) on delete cascade primary key,
  email text,
  nickname text default '',
  is_activated boolean default false,
  plan text default 'free',
  created_at timestamptz default now(),
  last_login_at timestamptz
);

-- 设备/登录记录表（记录客户端登录情况）
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  device_name text,
  device_id text,
  last_seen_at timestamptz default now(),
  created_at timestamptz default now()
);

-- 统计数据表（预留：启动次数、功能使用量等）
create table if not exists public.stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade,
  event text,
  value jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- 新用户注册时自动创建 profile
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, nickname)
  values (new.id, new.email, split_part(new.email, '@', 1));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 行级安全（RLS）：用户只能访问自己的数据
alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.stats enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "devices_select_own" on public.devices;
create policy "devices_select_own" on public.devices
  for select using (auth.uid() = user_id);

drop policy if exists "devices_insert_own" on public.devices;
create policy "devices_insert_own" on public.devices
  for insert with check (auth.uid() = user_id);

drop policy if exists "stats_select_own" on public.stats;
create policy "stats_select_own" on public.stats
  for select using (auth.uid() = user_id);

drop policy if exists "stats_insert_own" on public.stats;
create policy "stats_insert_own" on public.stats
  for insert with check (auth.uid() = user_id);
