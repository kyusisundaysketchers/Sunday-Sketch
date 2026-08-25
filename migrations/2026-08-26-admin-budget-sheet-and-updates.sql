-- ---------------------------------------------------------------------
-- Patch · 26 August 2026 (second pass, same day)
-- Brings rows already seeded from the meeting-notes migration up to date
-- with: the budget control sheet link, the break moving to the middle
-- of the programme (after station two), and capacity opening to 30
-- (10 per colour group) in the admin-only content.
--
-- Run this ONLY if you already ran migrations/2026-08-26-meeting-notes-
-- and-budget.sql and re-ran sections 4-6 of supabase-schema.sql before
-- today. If you have not run that yet, skip this file — just run the
-- current supabase-schema.sql sections 4-6 once, they already include
-- everything below.
--
-- Nothing here touches the public page. The 30-capacity figures are
-- admin-only; the public site still reads 24 / eight per group.
-- ---------------------------------------------------------------------

begin;

update budget_items
set category = 'Food · 30 pax package'
where category = 'Food · 24 pax package';

update open_items
set label = 'Food package quote for 30'
where label = 'Food package quote for 24';

update admin_content
set payload = payload || '{
  "text": "Figures track KSS_Event_Budget_Control.xlsx. Known working costs total ₱5,240 (models ₱4,500, ads ₱500, poster ₱240). Venue, food, materials, props, incidentals and contingency are all still unpriced, so that total is not the event budget. The model rate is now ₱1,500 each, replacing the earlier ₱3,000 each and the ₱9,000/₱10,000 allocation. The workbook''s 24 × ₱1,000 = ₱24,000 registration-revenue assumption predates the move to 30 places and has not been recalculated; that figure and any updated one remain planning assumptions only, and no price is published on the public site. The earlier handwritten ₱11,500 and ₱43,000 have no components behind them and should not be quoted.",
  "sheet_url": "https://docs.google.com/spreadsheets/d/1_s2qUACdDn79Tnj9gb95hZ4O6tPLokXJ1-A8tIX5yDs/edit?gid=1705866675#gid=1705866675"
}'::jsonb
where section_key = 'budget_note';

update admin_content
set payload = payload || '{
  "groups": [
    {"colour":"cy","name":"Cyan","seats":10,"seats_label":"10 seats · group 1","stations":["Station 1","Station 2","Station 3"]},
    {"colour":"rd","name":"Red","seats":10,"seats_label":"10 seats · group 2","stations":["Station 2","Station 3","Station 1"]},
    {"colour":"or","name":"Orange","seats":10,"seats_label":"10 seats · group 3","stations":["Station 3","Station 1","Station 2"]}
  ],
  "seats_note": "30 maximum, 10 per group. The meeting first floated 8–10 per station; capacity has since been opened up to 30."
}'::jsonb
where section_key = 'groups_ops';

update admin_content
set payload = payload || '{
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
  ]
}'::jsonb
where section_key = 'run_of_show';

update admin_content
set payload = payload || '{
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
}'::jsonb
where section_key = 'contingencies';

commit;

-- ---------------------------------------------------------------------
-- Verify afterwards:
--   select category from budget_items where category like 'Food %';
--     -- expect 'Food · 30 pax package'
--   select label from open_items where label like 'Food package quote%';
--     -- expect 'Food package quote for 30'
--   select payload->'sheet_url' from admin_content where section_key = 'budget_note';
--     -- expect the Google Sheet URL
--   select jsonb_array_length(payload->'slots') from admin_content where section_key = 'run_of_show';
--     -- expect 12 (was 11 before this patch — the extra transition slot)
--   select payload->'groups' from admin_content where section_key = 'groups_ops';
--     -- expect seats:10 on all three groups
-- ---------------------------------------------------------------------
