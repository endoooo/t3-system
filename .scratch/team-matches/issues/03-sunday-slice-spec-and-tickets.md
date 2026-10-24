# Sunday slice spec and tickets

Type: task
Status: resolved
Blocked by: 01, 02

## Question

Write `.scratch/team-matches/spec.md` and the `ready-for-agent` implementation tickets for the Sunday slice from the resolved decisions, then build them (Sunday lane override in the map's Notes).

## Comments

- Spec written: `.scratch/team-matches/spec.md`. Implementation tickets 04–08 (`ready-for-agent`). Order: 04 → 05 → {06 → 07, 08}. Stays claimed until the build is done.

## Answer

Built on branch `team-matches` (tickets 04–08 plus code-review fixes, commits f84a854..7f5ec5a). Team categories, team registrations, team matches in groups/brackets/matches tab, the team match page with inner matches (lineups, positions, scoring, manual winner), team standings tiebreaks, and inner matches on the schedule, counts and overview. A bracket slot can't change team while its team match has inner matches.
