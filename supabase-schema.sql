-- ---------------------------------------------------------------------
-- Kyusi Sunday Sketchers — 1st Anniversary · Fiestang Pinoy
-- Admin schema + seed data
--
-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).
-- It is safe to run more than once: every statement is idempotent and the
-- seeds use ON CONFLICT DO NOTHING, so re-running will never overwrite
-- edits the organisers have made or reset checklist progress.
--
-- PRIVATE FILE. This contains internal planning content. Do not deploy it
-- as part of the public GitHub Pages site.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

create table if not exists admins (
  user_id uuid primary key references auth.users(id),
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
  section_key text primary key,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

-- section_key values the site reads:
--   models · venue · registration_details · next_meeting · budget_note
--   run_of_show · groups_ops · roles · early_arrivals · contingencies
--   ingress · egress
-- Any key with no row renders a neutral "Not set up" panel in Admin.


-- ---------------------------------------------------------------------
-- 2. Authorization
-- ---------------------------------------------------------------------

-- SECURITY DEFINER so it can read `admins` (which has no client-facing
-- policies) on the caller's behalf. The search_path is pinned so the
-- function cannot be tricked into reading a different `admins` table.
create or replace function is_admin()
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;


-- ---------------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------------

alter table budget_items  enable row level security;
alter table open_items    enable row level security;
alter table admin_content enable row level security;
alter table admins        enable row level security; -- no policies = deny all direct client access

drop policy if exists "admins can read budget"        on budget_items;
drop policy if exists "admins can read open items"    on open_items;
drop policy if exists "admins can update open items"  on open_items;
drop policy if exists "admins can read admin content" on admin_content;

create policy "admins can read budget"        on budget_items  for select using (is_admin());
create policy "admins can read open items"    on open_items    for select using (is_admin());
create policy "admins can update open items"  on open_items    for update using (is_admin());
create policy "admins can read admin content" on admin_content for select using (is_admin());


-- ---------------------------------------------------------------------
-- 4. Budget
-- ---------------------------------------------------------------------

-- Working figures come from KSS_Event_Budget_Control.xlsx (Master Budget).
-- quoted_amount stays null throughout: the Vendor Quotes sheet marks every
-- figure "Working Estimate" or "Pending", so nothing is a real quotation yet.
insert into budget_items (category, working_amount, alt_amount, quoted_amount, sort_order) values
  ('Venue · extended rental', null, null, null, 0),
  ('Models · 3 × ₱1,500', 4500, null, null, 1),
  ('Food · 30 pax package', null, null, null, 2),
  ('Marketing · digital advertising', 500, null, null, 3),
  ('Printing · event poster', 240, null, null, 4),
  ('Materials · art and event supplies', null, null, null, 5),
  ('Costumes and props', null, null, null, 6),
  ('Incidentals', null, null, null, 7),
  ('Contingency reserve', null, null, null, 8)
on conflict (category) do nothing;


-- ---------------------------------------------------------------------
-- 5. Open decisions
--
-- DO NOTHING, never DO UPDATE — a re-run must not reset `done` and wipe
-- the organisers' progress.
-- ---------------------------------------------------------------------

insert into open_items (label, sort_order) values
  ('Final venue and rental hours', 0),
  ('Exact event start and end time', 1),
  ('Proper pose duration', 2),
  ('Exact station rotation schedule', 3),
  ('Break duration and food arrangements', 4),
  ('Challenge mechanics', 5),
  ('Model schedule', 6),
  ('Final budget and downpayment', 7),
  ('Registration fee: is the event paid, and at what price', 19),
  ('Extended venue rental quote', 20),
  ('Food package quote for 30', 21),
  ('Contingency reserve amount', 22),
  ('Final registration and group assignment process', 8),
  ('Colour set for the three groups', 9),
  ('Age restriction and waiver', 10),
  ('Seating requirements', 11),
  ('Signage and printing quantity', 12),
  ('Owner for marketing and social', 13),
  ('Owner for materials and chairs', 14),
  ('Final venue layout', 15),
  ('Event roles assigned', 16),
  ('Early arrival area and owner', 17),
  ('Operational dry run completed', 18)
on conflict (label) do nothing;


-- ---------------------------------------------------------------------
-- 6. Admin content
--
-- `status`, `status_note` and `status_flag` drive the Dashboard tiles.
-- status_flag = true renders the tile in red.
-- ---------------------------------------------------------------------

insert into admin_content (section_key, payload) values

('models', '{
  "status": "Names TBC",
  "status_note": "₱1,500 each is a working estimate, not an agreed fee.",
  "eyebrow": "Names TBC",
  "rate_note": "Working rate is now ₱1,500 each — ₱4,500 for the three — per the updated discussion and the budget control sheet. This replaces the earlier ₱3,000 each and the ₱9,000/₱10,000 allocation. Still a working estimate, not an agreed fee.",
  "items": [
    {"text":"Availability and fee per model","open":true},
    {"text":"Which model takes which themed station","open":true},
    {"text":"Filipino-inspired concept and styling per station","open":true},
    {"text":"Backup models if the first choices decline","open":false}
  ],
  "note": "Model names in the transcript are unclear. Do not treat any name as booked until the fee is agreed."
}'::jsonb),

('venue', '{
  "status": "Layout zones set",
  "status_note": "Seating count still open until the layout is locked.",
  "layout_zones": ["Three station areas","LATAG / common area","Registration and entrance","Food and snacks","Tarp and signage"],
  "bring_on_day": ["Colour tags and name tags","Attendance sheet","One trash bag per station","Tape and basic station materials","Monoblock chairs, only if needed"],
  "spend_note": "Use the benches and floor seating first. Reuse the generic tarp if one exists, and print A3 posters for anything event specific. Buy a new large tarp only if the venue needs it.",
  "spend_tag": "Seating count after layout is locked",
  "latag_note": "LATAG is the common area session in the open space, not a fourth station. A one-minute sketch challenge was floated for this slot. It is an option, not a decision.",
  "claygo_note": "Clean as you go, with a trash bag at every station. Confirm the bag size and count with the venue before the day."
}'::jsonb),

('registration_details', '{
  "status": "Not open",
  "status_note": "Blocked on the age rule and the waiver.",
  "status_flag": true,
  "blocker_lede": "This one gates everything else. Registration cannot open until the age rule and the waiver are agreed, because one of the three stations is artistic nude figure drawing.",
  "decide": ["Minimum age","PG-13 restriction, or 18+","Guardian consent, if minors are allowed","Whether the age rule applies to the whole event or only to the Artistic Nude station"],
  "write": ["Waiver wording","Consent line on the form","House rules on photos"],
  "update": ["Google Form fields","Age question, required","Confirmation email copy"],
  "order_of_work": "Agree the age rule, then update the form, then open registration. Do not promote the link before the form is correct. The public page already tells attendees that entry and eligibility requirements are published with the form, so the policy has to exist before registration opens."
}'::jsonb),

('next_meeting', '{
  "month": 8, "day": 25, "hour": 22, "minute": 0,
  "blurb": "This meeting moves the plan from brainstorm to confirmation. Bring a status, a quotation or a recommendation for whatever you own.",
  "bring": [
    {"label":"Venue.","text":"Final venue and rental hours, then exact start and end times."},
    {"label":"Flow.","text":"Proper-pose duration, rotation schedule, break length, challenge mechanics."},
    {"label":"Models.","text":"Three names, fees agreed, styling per themed station."},
    {"label":"Registration.","text":"Age rule decided, form updated, waiver drafted."},
    {"label":"Logistics.","text":"Venue layout, seating count, tags, trash bags, printing."},
    {"label":"Marketing.","text":"Save the date asset, ad budget, owner per platform."},
    {"label":"Budget.","text":"One consolidated sheet with quotations replacing guesses."},
    {"label":"Roles.","text":"A name against every role on the roles sheet."},
    {"label":"Dry run.","text":"Book the operational run-through: registration, rotations, timer, model transitions, announcements, break flow, closing."}
  ]
}'::jsonb),

('budget_note', '{
  "text": "Figures track KSS_Event_Budget_Control.xlsx. Known working costs total ₱5,240 (models ₱4,500, ads ₱500, poster ₱240). Venue, food, materials, props, incidentals and contingency are all still unpriced, so that total is not the event budget. The model rate is now ₱1,500 each, replacing the earlier ₱3,000 each and the ₱9,000/₱10,000 allocation. The workbook's 24 × ₱1,000 = ₱24,000 registration-revenue assumption predates the move to 30 places and has not been recalculated; that figure and any updated one remain planning assumptions only, and no price is published on the public site. The earlier handwritten ₱11,500 and ₱43,000 have no components behind them and should not be quoted.",
  "sheet_url": "https://docs.google.com/spreadsheets/d/1_s2qUACdDn79Tnj9gb95hZ4O6tPLokXJ1-A8tIX5yDs/edit?gid=1705866675#gid=1705866675"
}'::jsonb),

('run_of_show', '{
  "status": "Under revision",
  "status_note": "Venue hours being extended. No times published.",
  "status_flag": true,
  "lede": "The production sequence. Following the latest meeting the venue rental is being extended to around five hours with a tentative 8:45–9:00 AM start, so no clock times are fixed and none are published. The public page shows this structure only.",
  "slots": [
    {
      "time": "Before doors",
      "name": "Ingress and setup",
      "body": [
        "Venue access, then set the three themed stations, lay out materials, tape the signage, and put a trash bag at each station.",
        "Registration opens as soon as the desk is ready. Early attendees are welcomed and directed while active setup areas stay controlled."
      ]
    },
    {
      "time": "Doors",
      "name": "Registration and check-in",
      "body": [
        "Attendance, name tags, and the colour tag that assigns each attendee to a group.",
        "Group assignment happens here, not later. Confirm the final process and the colour set before printing tags."
      ]
    },
    {
      "time": "Opening",
      "name": "Short welcome",
      "body": [
        "Deliberately brief. House rules, station map, rotation, clean-as-you-go, and the rules around photographing the models.",
        "Agreed: no lengthy individual introductions. Keep administrative time off the programme."
      ]
    },
    {
      "time": "Rotation",
      "name": "Station 1 · themed",
      "accent": "st1",
      "body": [
        "Short warm-up, around 3 minutes, then one longer proper pose. Run from Live event control.",
        "Proper-pose duration is not yet decided."
      ]
    },
    {
      "time": "Rotation",
      "name": "Transition",
      "body": [
        "Groups move together to the next station."
      ]
    },
    {
      "time": "Rotation",
      "name": "Station 2 · themed",
      "accent": "st2",
      "body": [
        "Same shape: warm-up, then the proper pose."
      ]
    },
    {
      "time": "Break",
      "name": "Food and rest",
      "body": [
        "A proper break for artists and models both, in the middle of the morning, with time for snacks and socialising.",
        "Break length and food arrangements not yet confirmed."
      ]
    },
    {
      "time": "Rotation",
      "name": "Transition",
      "body": [
        "Groups move together to the final station."
      ]
    },
    {
      "time": "Rotation",
      "name": "Station 3 · themed",
      "accent": "st3",
      "body": [
        "Third theme, third model, final proper pose."
      ]
    },
    {
      "time": "Closing",
      "name": "Anniversary challenge",
      "body": [
        "Special activity in the latter part of the event. Mechanics and timing not yet confirmed."
      ]
    },
    {
      "time": "Closing",
      "name": "Photos and close",
      "body": [
        "Group photos, photos with the models, artwork photos, and the closing."
      ]
    },
    {
      "time": "After",
      "name": "Egress and handover",
      "flag": "Hard stop",
      "body": [
        "Pack down, clean, inspect and hand the venue back within the rental window."
      ]
    }
  ],
  "note": "Still to finalise: venue and rental hours, exact start and end, proper-pose duration, rotation schedule, break length, challenge mechanics, model schedule. Do not publish a minute-by-minute schedule until these are agreed."
}'::jsonb),

('groups_ops', '{
  "status": "Proposed only",
  "status_note": "Rotation and colour set both unconfirmed. Do not print tags yet.",
  "lede": "Colour tags decide where each group starts and where it goes next. The rotation below is the straight loop from the planning notes and is still a proposal.",
  "caption": "Proposed rotation — not yet confirmed",
  "groups": [
    {"colour":"cy","name":"Cyan","seats":10,"seats_label":"10 seats · group 1","stations":["Station 1","Station 2","Station 3"]},
    {"colour":"rd","name":"Red","seats":10,"seats_label":"10 seats · group 2","stations":["Station 2","Station 3","Station 1"]},
    {"colour":"or","name":"Orange","seats":10,"seats_label":"10 seats · group 3","stations":["Station 3","Station 1","Station 2"]}
  ],
  "seats_note": "30 maximum, 10 per group. The meeting first floated 8–10 per station; capacity has since been opened up to 30.",
  "tags_title": "Why colour tags",
  "tags_note": [
    "Each group knows its next station without being told twice.",
    "Groups do not cross paths during transitions.",
    "Station leads can count heads fast.",
    "Tags are cheap and reusable for future events."
  ],
  "open_note": "Still open: the colour set is illustrative — orange, pink and red were floated at the latest meeting — and the rotation order is not agreed. Confirm both the colours and the full matrix before anything is printed on tags or station signs. The public page names no colours."
}'::jsonb),

('roles', '{
  "status": "Unassigned",
  "status_note": "No names against any role yet.",
  "status_flag": true,
  "intro": "Every role needs a name before the event. Add an \"owner\" to a row here and the placeholder disappears in Admin.",
  "rows": [
    {"role":"Event Lead","responsibility":"Owns the clock and the GO decisions. Final call on any change on the day."},
    {"role":"Host / Facilitator","responsibility":"Runs the 9:40 briefing and speaks to the room between sessions."},
    {"role":"Registration / Welcome","responsibility":"Check-in, colour tags, name tags, attendance sheet, late arrivals."},
    {"role":"Floor / Flow Lead","responsibility":"Moves groups between stations and keeps transitions tight."},
    {"role":"Station Lead · Amorsolo-ish","responsibility":"Runs the pose sequence and the timer at their station."},
    {"role":"Station Lead · Artistic Nude","responsibility":"Runs the pose sequence and the timer at their station."},
    {"role":"Station Lead · Encanto","responsibility":"Runs the pose sequence and the timer at their station."},
    {"role":"Timekeeper","responsibility":"Owns the master programme clock against 9:40, 12:40 and 1:00."},
    {"role":"Model Liaison","responsibility":"Single point of contact for the models: call times, breaks, comfort, fees."},
    {"role":"Venue Liaison","responsibility":"Venue contact, access, house rules, inspection and handover."},
    {"role":"Photographer / Content","responsibility":"Captures the day within the agreed photo rules."}
  ]
}'::jsonb),

('early_arrivals', '{
  "status": "Owner unassigned",
  "status_note": "Area and owner still to be named.",
  "intro": "Internal procedure for 9:00–9:40, while the space is still being set up. The public page only tells attendees to check in with the registration team and that the programme starts at 9:40.",
  "steps_title": "Procedure",
  "steps": [
    "Venue setup continues — active setup areas stay controlled",
    "Registration goes live as soon as the desk is ready",
    "Early attendees are welcomed at the entrance",
    "Attendees are directed to the early-arrival area and given the 9:40 start time",
    "Attendees enter the event area only when the team is ready",
    "Official programme begins at 9:40 with the welcome briefing"
  ],
  "owners_note": "Not yet assigned. Agree both at the next meeting, then add \"area\" and \"owner\" to this payload."
}'::jsonb),

('contingencies', '{
  "status": "None agreed",
  "status_note": "Known failure points with no plan behind them.",
  "status_flag": true,
  "intro": "Known failure points with no agreed plan. These are prompts for the next meeting, not decisions.",
  "rows": [
    {"when":"A model arrives late or cannot attend","status":"No plan agreed. Backup models are still an open point."},
    {"when":"A station runs over its sequence","status":"No plan agreed. Who calls the cut is not assigned."},
    {"when":"The challenge runs long or has to be cut","status":"No plan agreed. Mechanics and timing not yet confirmed."},
    {"when":"Attendance is under or over the 30 places","status":"No plan agreed. Group sizes and the over-capacity rule are not set."},
    {"when":"Timer device fails or runs out of battery","status":"No plan agreed. No backup device or manual fallback named."},
    {"when":"Venue access is delayed past 9:00","status":"No plan agreed. No revised setup order for a late start."},
    {"when":"An attendee needs first aid","status":"No plan agreed. No first-aid owner or kit location recorded."},
    {"when":"A photography or conduct issue during a session","status":"No plan agreed. Photo house rules are still being drafted."}
  ]
}'::jsonb),

('ingress', '{
  "intro": "Everything between venue access and the 9:40 GO. Work top to bottom; the Event Lead owns the final call.",
  "items": [
    "Venue access confirmed with the venue contact",
    "Walkthrough of the full space completed",
    "Room condition checked and any damage photographed",
    "Furniture arranged to the agreed layout",
    "Amorsolo-ish, Artistic Nude and Encanto stations set and materials laid out",
    "Model areas prepared and privacy checked with each model",
    "Registration desk live: attendance sheet, colour tags, name tags",
    "Group assignment process rehearsed with the registration team",
    "Signage and directional posters up",
    "Timer device charged, loaded and tested with sound",
    "Equipment check: seating, tape, trash bags at every station",
    "Early-arrival owner in position and briefed",
    "Staff positions confirmed against the roles list",
    "Final readiness sweep of the whole space",
    "Event Lead gives the GO for the welcome"
  ]
}'::jsonb),

('egress', '{
  "intro": "12:40 to 1:00 PM. The venue has to be handed back at 1:00 — treat it as a hard deadline, not a target.",
  "items": [
    "Group photos, model photos and artwork photos done before pack-down",
    "All attendees cleared from the station areas",
    "Equipment collected and counted back",
    "Artwork and personal materials returned to owners",
    "Signage, tape and tarps removed",
    "Furniture restored to the venue original layout",
    "Stations cleaned, floors clear",
    "Trash bagged and disposed of per venue instructions",
    "Lost and found collected and an owner named for it",
    "Venue inspection walkthrough with the venue contact",
    "Handover confirmed with the venue contact",
    "Final exit — everyone out within the rental window"
  ]
}'::jsonb)

on conflict (section_key) do nothing;


-- ---------------------------------------------------------------------
-- 7. IF YOU SEEDED FROM AN EARLIER VERSION OF THIS FILE
--
-- Section 6 uses ON CONFLICT DO NOTHING, so rows that already exist are
-- left alone and will still hold the pre-meeting content. To take the
-- revised operational content, delete those rows and re-run section 6.
-- This drops no organiser data other than the payloads themselves.
--
-- Skip any section_key whose payload you have edited by hand.
-- ---------------------------------------------------------------------

-- delete from admin_content where section_key in
--   ('run_of_show','groups_ops','next_meeting','ingress','egress','contingencies');
-- -- then re-run section 6 above.

-- Superseded budget categories. The new rows in section 4 use different
-- category names, so without this delete the old and new sets coexist.
-- delete from budget_items where category in (
--   'Models · 3','Costumes and styling','Materials','Food and snacks',
--   'Marketing and ads','Printing and posters','Tarp and signage',
--   'Seating','Miscellaneous'
-- );
-- -- and refresh the note:
-- delete from admin_content where section_key in ('budget_note','models');
-- -- then re-run sections 4 and 6.

-- Superseded open items. Deleting these loses their tick state; the
-- replacements are inserted by section 5.
-- delete from open_items where label in (
--   'Venue window: 40/180/20 vs 30/180/30',
--   'Station and break times inside 9:40–12:40',
--   'Long pose: 10 or 15 minutes',
--   'Colour group rotation',
--   'LATAG and challenge format',
--   'Model selection and fees',
--   'Final event budget',
--   'Food and snack arrangement'
-- );


-- ---------------------------------------------------------------------
-- 7b. OPTIONAL — add Dashboard status fields to rows that already exist
--
-- Section 6 will not touch rows seeded by the earlier version of this
-- file, so the five original sections have no status/status_note yet and
-- their Dashboard tiles read "In the database". These merges add only the
-- missing keys and leave the rest of each payload untouched.
-- Run them once if you seeded the database before this file.
-- ---------------------------------------------------------------------

-- update admin_content set payload = payload || '{"status":"Names TBC","status_note":"Fees and styling per station still open."}'::jsonb where section_key = 'models';
-- update admin_content set payload = payload || '{"status":"Layout zones set","status_note":"Seating count still open until the layout is locked."}'::jsonb where section_key = 'venue';
-- update admin_content set payload = payload || '{"status":"Not open","status_note":"Blocked on the age rule and the waiver.","status_flag":true}'::jsonb where section_key = 'registration_details';
-- update admin_content set payload = payload || '{"sheet_url":"https://docs.google.com/spreadsheets/d/1_s2qUACdDn79Tnj9gb95hZ4O6tPLokXJ1-A8tIX5yDs/edit?gid=1705866675#gid=1705866675"}'::jsonb where section_key = 'budget_note';


-- ---------------------------------------------------------------------
-- 7c. OPTIONAL — let Auth user deletion clean up the admins row
--
-- Without this, deleting an organiser in Authentication → Users fails on
-- the foreign key until their `admins` row is deleted first.
-- ---------------------------------------------------------------------

-- alter table admins drop constraint admins_user_id_fkey;
-- alter table admins add constraint admins_user_id_fkey
--   foreign key (user_id) references auth.users(id) on delete cascade;


-- ---------------------------------------------------------------------
-- 8. After running this file
--
-- 1. Authentication → Providers → turn OFF public sign-ups (defence in
--    depth; is_admin() already denies anyone not in `admins`).
-- 2. Authentication → Users → Add user, once per organiser account.
-- 3. For each user created, copy their UUID and run:
--      insert into admins (user_id, email) values ('<uuid>', 'name@example.com');
-- 4. Project Settings → API → confirm the Project URL and the publishable
--    (anon) key in index.html match this project. Never use service_role.
--
-- Verify the security model:
--   select relname, relrowsecurity from pg_class
--    where relname in ('admins','budget_items','open_items','admin_content');
--   select tablename, policyname, cmd from pg_policies where schemaname = 'public';
--   select proname, prosecdef, proconfig from pg_proc where proname = 'is_admin';
-- Expect: RLS true on all four, four policies and none on `admins`,
-- and is_admin with prosecdef = true and a search_path in proconfig.
-- ---------------------------------------------------------------------
