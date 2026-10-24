-- ============================================
-- SUPERB WELLNESS — DATABASE SETUP
-- ============================================
-- HOW TO USE THIS FILE:
-- 1. Log into supabase.com and open your project
-- 2. Click SQL Editor in the left sidebar
-- 3. Click New query
-- 4. Copy and paste this entire file into the box
-- 5. Click Run (bottom right)
-- 6. You should see: Success. No rows returned
-- That means everything worked correctly.
-- ============================================


-- ============================================
-- TABLE 1: Companies
-- Created when a manager signs up.
-- Stores the company name, join code, manager
-- details, which add-ons are enabled, and EAP.
-- ============================================
create table if not exists companies (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  join_code           text unique not null,
  manager_email       text not null,
  manager_name        text not null,
  plan                text default 'trial',
  trial_ends_at       timestamp default (now() + interval '60 days'),

  -- Add-ons (true = enabled)
  addon_holidays      boolean default false,
  addon_regulations   boolean default false,
  addon_courses       boolean default false,
  addon_ai_resources  boolean default false,

  -- EAP details set by the manager
  eap_name            text,
  eap_phone           text,
  eap_website         text,
  eap_description     text,

  -- Default holiday allowance for new employees
  default_allowance   int default 28,

  created_at          timestamp default now()
);


-- ============================================
-- TABLE 2: Employees
-- Created when an employee joins using a code.
-- Each employee belongs to one company.
-- ============================================
create table if not exists employees (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  display_name        text not null,
  role                text,

  -- Individual holiday allowance set by the manager
  -- Can differ per employee (part-time, contract, negotiated extra days)
  total_allowance     int default 28,

  joined_at           timestamp default now()
);


-- ============================================
-- TABLE 3: Weekly check-ins
-- Submitted once per week by employees.
-- Mood score 1-5. Never shown individually
-- to managers - only as team averages.
-- ============================================
create table if not exists checkins (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  employee_id         uuid references employees(id) on delete set null,
  mood                int not null check (mood between 1 and 5),
  note                text,
  week_start          date not null,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 4: Feedback messages
-- Sent via the mail centre. Can be anonymous
-- or named. Managers can reply to any message.
-- ============================================
create table if not exists feedback (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  employee_id         uuid references employees(id) on delete set null,
  is_anonymous        boolean default true,
  sender_name         text,
  category            text default 'general',
  message             text not null,
  is_urgent           boolean default false,
  manager_reply       text,
  replied_at          timestamp,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 5: Fitness challenges
-- Created by managers. Employees can join
-- and log their progress.
-- ============================================
create table if not exists challenges (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  name                text not null,
  type                text default 'steps',
  goal                int not null,
  end_date            date not null,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 6: Challenge entries
-- One row per employee per challenge.
-- Tracks each person's progress.
-- ============================================
create table if not exists challenge_entries (
  id                  uuid primary key default gen_random_uuid(),
  challenge_id        uuid references challenges(id) on delete cascade,
  employee_id         uuid references employees(id) on delete cascade,
  progress            int default 0,
  updated_at          timestamp default now()
);


-- ============================================
-- TABLE 7: Holiday requests
-- Submitted by employees. Managers approve
-- or deny. Tracks days used per employee.
-- ============================================
create table if not exists holiday_requests (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  employee_id         uuid references employees(id) on delete cascade,
  employee_name       text not null,
  department          text,
  start_date          date not null,
  end_date            date not null,
  days_count          int not null,
  reason              text,
  status              text default 'pending',
  manager_note        text,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 8: Company regulations
-- Uploaded by managers. All employees in the
-- company can read them in the Employee app.
-- ============================================
create table if not exists regulations (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  title               text not null,
  content             text not null,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 9: Training courses
-- Created by managers. Employees complete
-- them in the Employee app.
-- ============================================
create table if not exists courses (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  title               text not null,
  description         text,
  category            text default 'general',
  content             text,
  created_at          timestamp default now()
);


-- ============================================
-- TABLE 10: Course completions
-- One row per employee per completed course.
-- Lets managers track training progress.
-- ============================================
create table if not exists course_completions (
  id                  uuid primary key default gen_random_uuid(),
  course_id           uuid references courses(id) on delete cascade,
  employee_id         uuid references employees(id) on delete cascade,
  completed_at        timestamp default now()
);


-- ============================================
-- SECURITY: Row Level Security
-- This ensures each company can only ever
-- see and access their own data.
-- Think of it as a lock on each filing cabinet.
-- ============================================
alter table companies         enable row level security;
alter table employees         enable row level security;
alter table checkins          enable row level security;
alter table feedback          enable row level security;
alter table challenges        enable row level security;
alter table challenge_entries enable row level security;
alter table holiday_requests  enable row level security;
alter table regulations       enable row level security;
alter table courses           enable row level security;
alter table course_completions enable row level security;


-- Open access policies for now.
-- These allow the apps to read and write data.
-- Before going live with real paying customers
-- come back and we will tighten these up properly.
create policy "open" on companies          for all using (true);
create policy "open" on employees          for all using (true);
create policy "open" on checkins           for all using (true);
create policy "open" on feedback           for all using (true);
create policy "open" on challenges         for all using (true);
create policy "open" on challenge_entries  for all using (true);
create policy "open" on holiday_requests   for all using (true);
create policy "open" on regulations        for all using (true);
create policy "open" on courses            for all using (true);
create policy "open" on course_completions for all using (true);


-- ============================================
-- TABLE 11: One-to-ones
-- Scheduled by managers. Notes and actions.
-- Actions can be promoted into tasks (see
-- oneToOne_action_task_id).
-- ============================================
create table if not exists one_to_ones (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  employee_id         uuid references employees(id) on delete cascade,
  manager_email       text,
  scheduled_at        timestamp not null,
  status              text default 'upcoming',  -- upcoming | completed
  notes               text,
  created_at          timestamp default now()
);

create table if not exists one_to_one_actions (
  id                  uuid primary key default gen_random_uuid(),
  one_to_one_id       uuid references one_to_ones(id) on delete cascade,
  text                text not null,
  done                boolean default false,
  crm_task_id         uuid,   -- set once promoted into a task (see TABLE 12)
  created_at          timestamp default now()
);

-- ============================================
-- TABLE 12: Recognition
-- Lightweight manager -> employee recognition,
-- visible to the employee in their own app.
-- ============================================
create table if not exists recognitions (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  employee_id         uuid references employees(id) on delete cascade,
  manager_email       text,
  message             text not null,
  created_at          timestamp default now()
);

alter table one_to_ones        enable row level security;
alter table one_to_one_actions enable row level security;
alter table recognitions       enable row level security;
create policy "open" on one_to_ones        for all using (true);
create policy "open" on one_to_one_actions for all using (true);
create policy "open" on recognitions       for all using (true);


-- ============================================
-- FUNCTION: get_mood_aggregate
-- Returns ONLY counts per mood band for a
-- company — never individual rows. This is
-- what DB.wellbeing.aggregate() in manager.html
-- calls in live mode. The anonymity guarantee
-- lives here, at the query level, not in the
-- frontend's choice of what to render.
-- ============================================
create or replace function get_mood_aggregate(p_company_id uuid)
returns table(mood_band text, employee_count bigint)
language sql
security definer
as $$
  -- Most recent check-in per employee this week, bucketed, counted.
  -- No employee_id or employee-identifying column is ever selected out.
  select
    case
      when mood >= 5 then 'Great'
      when mood = 4 then 'Good'
      when mood = 3 then 'Okay'
      when mood = 2 then 'Low'
      else 'Struggling'
    end as mood_band,
    count(distinct employee_id) as employee_count
  from checkins
  where company_id = p_company_id
    and week_start = date_trunc('week', now())::date
  group by mood_band;
$$;


-- ============================================
-- TABLE 13: Customers (CRM)
-- One row per customer account, owned by a rep.
-- Health score is deliberately NOT stored here —
-- it's computed live from contact recency, open
-- tasks, and meeting sentiment (see manager.html
-- getCustomerHealth), same principle as mood:
-- a derived signal shouldn't be allowed to go
-- stale or drift from the data that produced it.
-- ============================================
create table if not exists customers (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  name                text not null,
  sector              text,
  location            text,
  rep_employee_id     uuid references employees(id) on delete set null,
  mrr                 numeric default 0,
  customer_since      date,
  last_contact_at     timestamp,
  ai_summary          text,   -- most recent AI relationship summary, manager/rep-approved
  created_at          timestamp default now()
);

-- ============================================
-- TABLE 14: Customer contacts
-- Named people at a customer. One can be primary.
-- ============================================
create table if not exists customer_contacts (
  id                  uuid primary key default gen_random_uuid(),
  customer_id         uuid references customers(id) on delete cascade,
  name                text not null,
  title               text,
  email               text,
  is_primary          boolean default false,
  created_at          timestamp default now()
);

-- ============================================
-- TABLE 15: Customer notes
-- Free-text notes a rep or manager adds. The
-- activity timeline shown in the UI is NOT a
-- separate table — it's assembled at query time
-- from notes + meetings + completed tasks, so
-- there is exactly one place each event is
-- written, never two copies that can disagree.
-- ============================================
create table if not exists customer_notes (
  id                  uuid primary key default gen_random_uuid(),
  customer_id         uuid references customers(id) on delete cascade,
  author_employee_id  uuid references employees(id) on delete set null,
  text                text not null,
  created_at          timestamp default now()
);

-- ============================================
-- TABLE 16: Meetings (CRM)
-- ============================================
create table if not exists meetings (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  customer_id         uuid references customers(id) on delete cascade,
  rep_employee_id     uuid references employees(id) on delete set null,
  purpose             text,
  format              text default 'video',   -- video | inperson
  scheduled_at        timestamp not null,
  status              text default 'upcoming', -- upcoming | completed
  notes               text,
  sentiment           int,   -- 0-100, set once an AI summary is approved
  customer_email      text,
  platform            text,
  meeting_link        text,
  manager_note        text,
  created_at          timestamp default now()
);

-- ============================================
-- TABLE 17: Tasks (shared by CRM follow-ups AND
-- 1-to-1 actions promoted into tasks — one task
-- system, not two, matching what the frontend
-- has always assumed).
-- ============================================
create table if not exists tasks (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  customer_id         uuid references customers(id) on delete set null, -- null = internal/people task
  rep_employee_id     uuid references employees(id) on delete set null,
  contact_name        text,
  text                text not null,
  due_date            date,
  urgent              boolean default false,
  done                boolean default false,
  source              text default 'Manual',  -- Manual | Meeting | AI | 1-to-1
  created_at          timestamp default now()
);

-- Now that a real tasks table exists, one_to_one_actions can properly
-- reference it once promoted (see manager.html: convertOtoActionToTask).
alter table one_to_one_actions add column if not exists crm_task_id uuid references tasks(id);

-- ============================================
-- TABLE 18: Opportunities (CRM pipeline)
-- ============================================
create table if not exists opportunities (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid references companies(id) on delete cascade,
  customer_id         uuid references customers(id) on delete cascade,
  description         text not null,
  value               numeric default 0,
  stage               text default 'identified', -- identified | proposal | won | lost
  close_date          date,
  created_at          timestamp default now()
);

alter table customers          enable row level security;
alter table customer_contacts  enable row level security;
alter table customer_notes     enable row level security;
alter table meetings           enable row level security;
alter table tasks              enable row level security;
alter table opportunities      enable row level security;
create policy "open" on customers          for all using (true);
create policy "open" on customer_contacts  for all using (true);
create policy "open" on customer_notes     for all using (true);
create policy "open" on meetings           for all using (true);
create policy "open" on tasks              for all using (true);
create policy "open" on opportunities      for all using (true);

-- ============================================
-- FUNCTION: get_mood_trend
-- Weekly average mood over the last N weeks, aggregate only — same
-- principle as get_mood_aggregate. This replaces what was static
-- placeholder data in the UI through Phase 1-5 (trendData); wired to
-- this function in Phase 6.
-- ============================================
create or replace function get_mood_trend(p_company_id uuid, p_weeks int default 8)
returns table(week_start date, avg_mood numeric, response_count bigint)
language sql
security definer
as $$
  select
    week_start,
    avg(mood)::numeric(10,2) as avg_mood,
    count(*) as response_count
  from checkins
  where company_id = p_company_id
    and week_start >= (date_trunc('week', now())::date - (p_weeks * 7))
  group by week_start
  order by week_start;
$$;


-- ============================================
-- NOTE: "External intelligence" (news mentions, Companies House
-- financial trend, AI estimate) shown on the meeting prep screen in
-- the demo has NO real data source and NO table here on purpose.
-- It is fabricated demo content. Do not launch this feature as-is —
-- either wire a real news/Companies House integration and a table to
-- cache its results, or remove the panel. See LAUNCH_CHECKLIST.md.
-- ============================================


-- ============================================
-- ALL DONE
-- You should see: Success. No rows returned
-- If you see that, everything worked correctly
-- and your database is ready to use.
-- ============================================
