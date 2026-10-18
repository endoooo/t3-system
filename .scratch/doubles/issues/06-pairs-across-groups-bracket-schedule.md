# 06: Pairs across groups, bracket and schedule

**What to build:** A doubles category runs end to end like a singles one. Superusers can add pairs to groups and bracket stages (the group-management picker lists pairs as "Ana / Bia"), schedule doubles matches on tables alongside singles matches, and record set scores and winners. Visitors see pairs as "Ana / Bia" with both avatars in group tables, bracket slots and schedule match cards, including the winner and final-standing (gold/silver) highlights. The schedule's player filter lists every player of every registration without duplicates, and filtering by a player shows matches where they're in either position of a pair, as well as their singles matches. This ticket mostly proves that 01, 02 and 04 hold together, and fixes whatever gaps it finds. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** 04 (Register a pair in a doubles category)

**Status:** resolved

- [x] Pairs can be added to groups and brackets. The group-management picker shows "Ana / Bia"
- [x] Group tables, bracket slots and schedule cards render pairs with both names and avatars
- [x] Winner and final-standing highlights work for pairs
- [x] Set scores and winners can be recorded for doubles matches
- [x] The schedule player filter lists every partner, and filtering by a player in position 2 shows their doubles matches together with their singles matches
- [x] Event page (PhoenixTest) tests cover the above
- [x] `mix precommit` passes

## Comments

- Tests: "doubles category" describe in `test/t3_system_web/live/event_live/show_test.exs`. Groups, bracket, score modal and schedule already rendered pairs through the shared helpers, so they needed no changes. The picker label includes clubs ("Ana — A / Bia — B"), like the singles "Name — Club".
- Gap fixed: the matches-tab player filter worked per category, so a player's singles and doubles matches (always in different categories) could never show together. Its options now list every player in any match of the event. While a player is selected, the tab shows their matches from every category, and each card is labeled with its category.
- Avatars: group tables and registration cards show both avatars, as they already did for singles. Bracket slots and match/schedule cards stay name-only ("Ana / Bia"), as for singles. Adding avatars there would be a separate UI change.
