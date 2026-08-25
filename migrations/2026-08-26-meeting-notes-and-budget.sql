-- ---------------------------------------------------------------------
-- Migration · 26 August 2026
-- Incorporates the latest meeting notes and KSS_Event_Budget_Control.xlsx
--
-- Run this ONLY if the database was already seeded from an earlier version
-- of supabase-schema.sql. On a fresh project, run supabase-schema.sql
-- instead — it already contains all of this content.
--
-- Step 1: run this file.
-- Step 2: re-run sections 4, 5 and 6 of supabase-schema.sql.
--
-- Nothing here touches the schema, the policies, is_admin(), or the
-- admins table. It only clears superseded content rows so the updated
-- seeds can land.
--
-- SKIP any DELETE below whose content you have edited by hand — a
-- re-seed will replace it with the version in supabase-schema.sql.
-- ---------------------------------------------------------------------

begin;

-- 1. Operational content superseded by the meeting notes.
--    run_of_show    — rebuilt around the new flow, with no clock times
--    groups_ops     — colour set now flagged as illustrative, not final
--    next_meeting   — agenda updated, dry run added
--    ingress        — group-assignment rehearsal added
--    egress         — photos moved before pack-down
--    contingencies  — challenge-overrun row added
delete from admin_content where section_key in (
  'run_of_show',
  'groups_ops',
  'next_meeting',
  'ingress',
  'egress',
  'contingencies'
);

-- 2. Budget content superseded by the control workbook.
--    models      — rate is now ₱1,500 each, not ₱3,000
--    budget_note — now tracks the workbook, and records the ₱24,000
--                  revenue assumption as an assumption
delete from admin_content where section_key in ('models', 'budget_note');

-- 3. Budget categories replaced. The new rows use different category
--    names, so without this the old and new sets would coexist.
delete from budget_items where category in (
  'Models · 3',
  'Costumes and styling',
  'Materials',
  'Food and snacks',
  'Marketing and ads',
  'Printing and posters',
  'Tarp and signage',
  'Seating',
  'Miscellaneous'
);

-- 4. Open decisions closed out or superseded by the meeting.
--    Deleting these loses their tick state. The replacements — including
--    the nine "still to finalise" items from the notes — are inserted by
--    section 5 of supabase-schema.sql.
delete from open_items where label in (
  'Venue window: 40/180/20 vs 30/180/30',
  'Station and break times inside 9:40–12:40',
  'Long pose: 10 or 15 minutes',
  'Colour group rotation',
  'LATAG and challenge format',
  'Model selection and fees',
  'Final event budget',
  'Food and snack arrangement'
);

commit;

-- ---------------------------------------------------------------------
-- Now re-run sections 4, 5 and 6 of supabase-schema.sql.
--
-- Verify afterwards:
--   select section_key from admin_content order by section_key;
--     -- expect 12 rows
--   select category, working_amount from budget_items order by sort_order;
--     -- expect 9 rows, ₱4,500 / ₱500 / ₱240 costed, the rest null
--   select count(*) from open_items;
--     -- expect 23
-- ---------------------------------------------------------------------
