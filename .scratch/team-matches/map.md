# Team matches

Label: wayfinder:map

## Destination

A spec plus `ready-for-agent` tickets for team categories, built in two lanes: a **Sunday slice** (event on 2026-10-25: c1 with group stage + bracket, c2 as a 4-team round robin) decided and built first, then generalized.

## Notes

- Domain: table tennis tournaments. Read `GLOSSARY.md` (Team play section) and ADR-0001 (registration holds a list of players) before any ticket.
- Skills: `grilling` + `domain-modeling` for decisions; `tdd` for the build.
- **Override for the Sunday lane**: once its decision tickets are resolved, this map carries the build too (spec, tickets, implementation), not just planning. The post-Sunday lane stays planning-only.
- Guiding mindset (from the user): **a team match is a wrapper of matches**. Add as little team-match logic as possible; admins do things manually, as they do in singles/doubles events today.
- Settled while charting:
  - Terms: Team, Team match, Match (the singles/doubles games inside a team match, not "rubber"), Position, Lineup, Team match format. See `GLOSSARY.md`.
  - A team is a registration in a team-format category. No team size limits; the only rule is a player is in at most one team per event + category (already enforced for registrations).
  - Sunday has no format templates: admins freely add singles or doubles matches to a team match, each side carrying a free position label (e.g. "AB" vs "XY").
  - The one hard rule: a match side's players must belong to that side's team. A player may play several matches in one team match.
  - Team match winner is set manually (like matches today). Its score shown (e.g. "2–1") is derived from the match wins inside it. Bracket advancement stays manual, as today.
  - Group standings for teams: team match wins → match difference → set difference → point difference.
  - Matches inside a team match can run in parallel on different tables.
  - Display: group standings, brackets and the matches tab show team matches; clicking a team match expands it in place to show its matches. Ongoing/next sections and the admin table schedule show the individual matches (with their team match context).

## Decisions so far

<!-- one line per closed ticket -->

- [How a team match wraps matches](issues/01-how-a-team-match-wraps-matches.md): a team match is a `Match` in a group/bracket; its matches are `Match` rows with `team_match_id`, team registrations as sides, a match-players list and `position1/2` labels; teams get a name; winner manual, score derived (ADR-0002)
- [Team match overlay and admin flow](issues/02-team-match-overlay-and-admin-flow.md): no overlay; the team match card expands in place showing the existing match cards; its footer (like a match card's) has "Adicionar partida" and "Resultado" (team match winner)

## Not yet specified

- **Team match formats (post-Sunday)**: templates such as "AB x XY, C x Z, A x X, best of 3", probably attached to the stage (c1 groups bo3, brackets bo5), generating a team match's matches. Shape: an ordered list of position-based matches plus a win target, covering ITTF World Team Champs, Olympic and Swaythling formats.
- **Automation (post-Sunday)**: deriving the team match winner, skipping remaining matches once a side reaches the win target, auto-advancing bracket winners.
- **Ranking extras (post-Sunday)**: head-to-head among tied teams; per-player results from matches played inside team matches.
- **Walkovers and byes for teams**: how `is_bye` / missing teams behave for a team match vs its matches.
- **Event dashboards/metrics**: whether counts (per category, by status, per table) count team matches, matches, or both.

## Out of scope

- Team size limits (min/max players per team): ruled out while charting; only the one-team-per-category rule applies.
- Lineup validation rules (fixed positions, distinct players per position, freely chosen doubles pairs): positions are free labels.
- Hidden lineups until both teams submit: admins enter everything.
