-- =========================
-- EPI Control - Schema MVP
-- PostgreSQL / Supabase
-- =========================

-- 1) Tables "meta"
create table if not exists chefs (
  id text primary key,
  name text not null
);

create table if not exists teams (
  id text primary key,
  name text not null,
  chef_id text references chefs(id) on update cascade on delete set null
);

-- 2) Workers
-- status = état global sur la liste (OK/KO)
-- attendance = PRESENT/ABS
-- controlled = est-ce qu'un contrôle a été validé (true/false)
create table if not exists workers (
  id text primary key,
  team_id text not null references teams(id) on update cascade on delete cascade,
  name text not null,
  employee_number text unique,
  role text, -- rôle de mission (ex: debroussailleur)
  attendance text not null default 'PRESENT' check (attendance in ('PRESENT', 'ABS')),
  status text not null default 'OK' check (status in ('OK', 'KO')),
  controlled boolean not null default false,
  last_check_at timestamptz
);

create index if not exists idx_workers_team_id on workers(team_id);
create index if not exists idx_workers_attendance on workers(attendance);
create index if not exists idx_workers_status on workers(status);

-- 3) Equipment / Roles
create table if not exists roles (
  id text primary key,
  label text not null
);

create table if not exists equipment (
  id text primary key,
  name text not null
);

-- mapping: quel équipement est requis pour quel rôle
create table if not exists role_equipment (
  role_id text not null references roles(id) on update cascade on delete cascade,
  equipment_id text not null references equipment(id) on update cascade on delete cascade,
  primary key (role_id, equipment_id)
);

-- 4) Checks (contrôles) + items
-- Un contrôle = une validation envoyée par l'app
create table if not exists checks (
  id bigserial primary key,
  worker_id text not null references workers(id) on update cascade on delete cascade,
  team_id text not null references teams(id) on update cascade on delete cascade,
  role text,
  result text not null check (result in ('CONFORME', 'NON_CONFORME')),
  created_at timestamptz not null default now()
);

create index if not exists idx_checks_team_created_at on checks(team_id, created_at);
create index if not exists idx_checks_worker_created_at on checks(worker_id, created_at);

create table if not exists check_items (
  id bigserial primary key,
  check_id bigint not null references checks(id) on update cascade on delete cascade,
  equipment_id text not null references equipment(id) on update cascade on delete restrict,
  status text not null check (status in ('OK', 'MANQUANT', 'KO'))
);

create index if not exists idx_check_items_check_id on check_items(check_id);