# 06: Pairs across groups, bracket and schedule

**What to build:** A doubles category runs end to end like a singles one. Superusers can add pairs to groups and bracket stages (the group-management picker lists pairs as "Ana / Bia"), schedule doubles matches on tables alongside singles matches, and record set scores and winners. Visitors see pairs as "Ana / Bia" with both avatars in group tables, bracket slots and schedule match cards, including the winner and final-standing (gold/silver) highlights. The schedule's player filter lists every player of every registration without duplicates, and filtering by a player shows matches where they're in either position of a pair, as well as their singles matches. This ticket mostly proves that 01, 02 and 04 hold together, and fixes whatever gaps it finds. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** 04 (Register a pair in a doubles category)

**Status:** ready-for-agent

- [ ] Pairs can be added to groups and brackets. The group-management picker shows "Ana / Bia"
- [ ] Group tables, bracket slots and schedule cards render pairs with both names and avatars
- [ ] Winner and final-standing highlights work for pairs
- [ ] Set scores and winners can be recorded for doubles matches
- [ ] The schedule player filter lists every partner, and filtering by a player in position 2 shows their doubles matches together with their singles matches
- [ ] Event page (PhoenixTest) tests cover the above
- [ ] `mix precommit` passes

## Comments
