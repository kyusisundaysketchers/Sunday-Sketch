-- Kyusi Sunday Sketchers — Admin schema
-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).
-- It creates the tables, the is_admin() authorization check, Row Level
-- Security policies, and seeds them with the site's current real content.
-- Safe to run more than once: table/policy/seed statements are all
-- idempotent, and re-running never overwrites data you've since edited
-- in the Supabase table editor (every seed insert is ON CONFLICT DO NOTHING).

create table if not exists admins (
  user_id uuid primary key,
  email text not null
);

create table if not exists budget_items (
  id uuid primary key default gen_random_uuid(),
  category text not null unique,
  working_amount numeric,
  alt_amount numeric,      -- only set for the row that has a toggleable alternative (Models)
  quoted_amount numeric,
  sort_order int not null default 0
);

create table if not exists open_items (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  done boolean not null default false,
  sort_order int not null default 0
);

create table if not exists admin_content (
  section_key text primary key,   -- 'models' | 'venue' | 'registration_details' | 'next_meeting' | 'budget_note'
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

-- Adds the unique constraints above onto a table that already existed from
-- an earlier run of this script (before this line was added). No-ops if
-- the constraint is already there, either way.
do $$ begin
  alter table budget_items add constraint budget_items_category_key unique (category);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table open_items add constraint open_items_label_key unique (label);
exception when duplicate_object then null;
end $$;

-- Cascade: deleting an auth user should also drop their admins row, not
-- block the delete. Drop-then-add is idempotent on its own (no need for
-- the duplicate_object guard used above).
alter table admins drop constraint if exists admins_user_id_fkey;
alter table admins add constraint admins_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

-- Server-side authorization check. SECURITY DEFINER so it can read `admins`
-- (which has no client-facing policies) on the caller's behalf.
create or replace function is_admin()
returns boolean language sql security definer stable as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

alter table budget_items enable row level security;
alter table open_items enable row level security;
alter table admin_content enable row level security;
alter table admins enable row level security; -- no policies below = deny all direct client access

drop policy if exists "admins can read budget" on budget_items;
create policy "admins can read budget" on budget_items for select using (is_admin());

drop policy if exists "admins can read open items" on open_items;
create policy "admins can read open items" on open_items for select using (is_admin());

drop policy if exists "admins can update open items" on open_items;
create policy "admins can update open items" on open_items for update using (is_admin());

drop policy if exists "admins can read admin content" on admin_content;
create policy "admins can read admin content" on admin_content for select using (is_admin());

-- RLS policies only take effect once the `authenticated` role has the
-- underlying table privilege in the first place — without this grant,
-- PostgREST returns a flat 403 before RLS is even consulted, regardless
-- of how correct the policies above are. Idempotent: GRANT is safe to
-- repeat.
grant usage on schema public to authenticated;
grant select on budget_items, open_items, admin_content to authenticated;
grant update on open_items to authenticated;

-- ---------------------------------------------------------------------
-- Seed data — reproduces the page's current real content exactly.
-- ---------------------------------------------------------------------

insert into budget_items (category, working_amount, alt_amount, quoted_amount, sort_order) values
  ('Models · 3', 9000, 10000, null, 0),
  ('Costumes and styling', null, null, null, 1),
  ('Materials', null, null, null, 2),
  ('Food and snacks', null, null, null, 3),
  ('Marketing and ads', null, null, null, 4),
  ('Printing and posters', null, null, null, 5),
  ('Tarp and signage', null, null, null, 6),
  ('Seating', null, null, null, 7),
  ('Miscellaneous', null, null, null, 8)
on conflict (category) do nothing;

insert into open_items (label, sort_order) values
  ('Model selection and fees', 0),
  ('Long pose: 10 or 15 minutes', 1),
  ('Colour group rotation', 2),
  ('Age restriction and waiver', 3),
  ('Final event budget', 4),
  ('Food and snack arrangement', 5),
  ('Seating requirements', 6),
  ('Signage and printing quantity', 7),
  ('LATAG and challenge format', 8),
  ('Owner for marketing and social', 9),
  ('Owner for materials and chairs', 10),
  ('Final venue layout', 11)
on conflict (label) do nothing;

insert into admin_content (section_key, payload) values
('models', '{
  "eyebrow": "Names TBC",
  "rate_note": "Working rate is around ₱3,000 each. The later discussion pushed the allocation towards ₱10,000 for the three.",
  "items": [
    {"text":"Availability and fee per model","open":true},
    {"text":"Clothed or nude, and which station","open":true},
    {"text":"Filipino-inspired concept and styling","open":false},
    {"text":"Backup models if the first choices decline","open":false}
  ],
  "note": "Model names in the transcript are unclear. Do not treat any name as booked until the fee is agreed."
}'::jsonb),

('venue', '{
  "layout_zones": ["Three station areas","LATAG / common area","Registration and entrance","Food and snacks","Tarp and signage"],
  "bring_on_day": ["Colour tags and name tags","Attendance sheet","One trash bag per station","Tape and basic station materials","Monoblock chairs, only if needed"],
  "spend_note": "Use the benches and floor seating first. Reuse the generic tarp if one exists, and print A3 posters for anything event specific. Buy a new large tarp only if the venue needs it.",
  "spend_tag": "Seating count after layout is locked",
  "latag_note": "LATAG is the common area session in the open space, not a fourth station. A one-minute sketch challenge was floated for this slot. It is an option, not a decision.",
  "claygo_note": "Clean as you go, with a trash bag at every station. Confirm the bag size and count with the venue before the day."
}'::jsonb),

('registration_details', '{
  "blocker_lede": "This one gates everything else. Registration cannot open until the age rule and the waiver are agreed, because the event may involve nude modelling.",
  "decide": ["Minimum age","PG-13 restriction, or 18+","Guardian consent, if minors are allowed"],
  "write": ["Waiver wording","Consent line on the form","House rules on photos"],
  "update": ["Google Form fields","Age question, required","Confirmation email copy"],
  "order_of_work": "Agree the age rule, then update the form, then open registration. Do not promote the link before the form is correct."
}'::jsonb),

('next_meeting', '{
  "month": 8, "day": 25, "hour": 22, "minute": 0,
  "blurb": "This meeting moves the plan from brainstorm to confirmation. Bring a status, a quotation or a recommendation for whatever you own.",
  "bring": [
    {"label":"Flow.","text":"Rotation sequence, final pose timing, LATAG format, real end time."},
    {"label":"Models.","text":"Three names, fees agreed, styling per station."},
    {"label":"Registration.","text":"Age rule decided, form updated, waiver drafted."},
    {"label":"Logistics.","text":"Venue layout, seating count, tags, trash bags, printing."},
    {"label":"Marketing.","text":"Save the date asset, ad budget, owner per platform."},
    {"label":"Budget.","text":"One consolidated sheet with quotations replacing guesses."}
  ]
}'::jsonb),

('budget_note', '{
  "text": "A handwritten ₱11,500 and a later ₱43,000 both appear in the notes. Neither has clear components behind it. Do not quote either as the event budget until the categories above are filled in."
}'::jsonb)
on conflict (section_key) do nothing;

-- ---------------------------------------------------------------------
-- Admin accounts
-- ---------------------------------------------------------------------
-- This does NOT need real UUIDs typed in by hand — it looks each user up
-- in auth.users by email, so it only works AFTER each account below has
-- been created in Authentication → Users (with a password set directly
-- in that dialog, so no invite/reset email is sent). Re-run it any time
-- after adding more accounts; already-admitted users are skipped.
--
-- NOTE: "cluelessrex@@gmail.com" has a double "@" and is not a valid
-- email address as written — it won't match any Supabase account, so
-- this insert silently skips it. Fix the address (single "@") and re-run
-- this block once you know the correct one.
--
-- NOTE: this list is five accounts, not the two the admin area's own
-- copy still says ("restricted to the two organisers who manage them" —
-- see index.html's Admin sign-in lede). Worth deciding whether that
-- wording should be updated, or the account list trimmed back to two.

insert into admins (user_id, email)
select id, email from auth.users
where email in (
  'rm202mnla@gmail.com',
  'vaughnpinpin@gmail.com',
  'manzano.rrt@gmail.com',
  'kyusisunday@gmail.com',
  'cluelessrex@gmail.com'  -- corrected from the double-@ typo; confirm this is right
)
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------
-- Full setup order:
--
-- 1. Run everything above this section once.
-- 2. Authentication → Providers → turn OFF public sign-ups (defense in
--    depth; is_admin() already denies anyone not in `admins` regardless).
-- 3. Authentication → Users → Add user → Create new user, once per
--    account above. Set the password directly in that dialog and toggle
--    Auto Confirm User on — this avoids Supabase's invite/reset email
--    (and its rate limit) entirely.
-- 4. Run the `insert into admins ...` block above (or re-run it after
--    adding more accounts later).
-- 5. Project Settings → API → copy the Project URL and the "anon public"
--    key into index.html, replacing YOUR_SUPABASE_PROJECT_URL and
--    YOUR_SUPABASE_ANON_KEY. Never use the "service_role" key here.
--    (Already done as of the "Support Supabase invitation password
--    setup" commit, if you're reading this after that.)
-- ---------------------------------------------------------------------
