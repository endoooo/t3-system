# 07: Inner matches on the schedule and overview

Status: ready-for-agent

**What to build:** The table schedule works with matches inside team matches and never with team matches: per-table finished/pending lists, the unscheduled pool (reaching category/stage through the team match), drag and drop, add to table, ongoing toggle and time recalculation include inner matches and exclude team matches. The unassigned-matches warning, matches-per-table, per-category and by-status counts count inner matches for team categories, not team matches. The overview's ongoing and next sections show inner matches. Inner match cards (overview, matches tab) and schedule cards carry the team match context ("AABB A x Clube Y · AB x XY") and the position labels; on match cards the context links to the team match page, schedule board cards don't link. Spec: `.scratch/team-matches/spec.md`.

**Blocked by:** 06 (Matches inside a team match)

- [ ] Schedule queries and actions include inner matches, exclude team matches
- [ ] Dashboard counts and unassigned warning exclude team matches
- [ ] Overview ongoing/next show inner matches with team match context
- [ ] Schedule card and match card labels show team match context and position labels; match card context links to the team match page
- [ ] Matches context and event page (PhoenixTest) tests cover the above
- [ ] `mix precommit` passes

## Comments
