# Team categories (Sunday slice)

Status: ready-for-agent

## Problem Statement

Organizers run team competitions: teams of players face each other in **team matches**, each made of singles and doubles matches whose players and order the teams choose for every team match (part of the strategy). The next event (2026-10-25) has two team categories: c1 with a group stage and a bracket, c2 as a single round robin of 4 teams. Today a **Registration** is a single player or a **Pair**, and a **Match** is one registration against another, so there's no way to register a team, put team matches in groups and brackets, or record the matches played inside a team match.

## Solution

A **Category** can have the `team` **Format**. Its registrations are **Teams**: a name and any number of players, each representing their own club. Teams go into groups and brackets like any registration, and the matches generated between them are **team matches**. A team match is a thin wrapper: a superuser adds singles or doubles matches to it by hand, picking each side's players from that side's team and writing a free **Position** label per side ("AB" vs "XY", "C" vs "Z"). Those matches are ordinary matches: scored in the usual score modal, scheduled on tables (several at once if wanted), flagged as ongoing. The superuser sets the team match winner by hand; its score ("2 — 1") is counted from the matches inside it. Visitors see team matches in group standings, brackets and the matches tab; clicking a team match (card or bracket slot) opens its **detail page**, which shows its matches as regular match cards and is where superusers manage it. The overview's ongoing/next sections and the table schedule show the matches inside team matches.

Decisions behind this: `GLOSSARY.md` (Team play), `docs/adr/0002-team-match-is-a-match-wrapping-matches.md`, and the wayfinder map `.scratch/team-matches/map.md` (tickets 01 and 02 hold the detail).

## User Stories

1. As a superuser, I want to create a category with the team format, so that the event can offer team competitions.
2. As a superuser, I want the team format locked once the category has registrations, like singles and doubles, so that existing registrations stay valid.
3. As a superuser, I want to register a team with a name and its players (each with their club), so that the team can be placed in groups and brackets.
4. As a superuser, I want to add or remove player rows in the team registration modal, so that teams of any size can be registered.
5. As a superuser, I want a clear error if a team has no name, no players, or the same player twice, so that broken teams can't be saved.
6. As a superuser, I want a player already in another team of the same event + category to be rejected, so that a player represents only one team per category.
7. As a superuser, I want to edit a team's name and players, so that I can fix mistakes and add a late player.
8. As a visitor, I want registration cards in a team category to show the team name with its players and clubs below, so that I know who makes up each team.
9. As a superuser, I want to add teams to groups and generate the group's matches, so that every pair of teams gets a team match.
10. As a visitor, I want group standings to list teams by name, ranked by team match wins, then match difference, then set difference, then point difference, so that I can follow the group.
11. As a visitor, I want the matches tab of a team category to list team matches as cards with both team names and the score counted from their matches, so that I can see every team match at a glance.
12. As a visitor, I want to click a team match card (matches tab) or bracket slot to open the team match's page, with its header (category, stage/group/round, teams, score, status) and its matches as regular match cards (position labels, players, sets, table, time, ongoing), so that I can follow it match by match.
13. As a superuser, I want an "Adicionar partida" action on the team match page, so that I can add the next match as the teams hand in their choices.
14. As a superuser, I want the add-match modal to ask for singles or doubles, a position label per side, each side's player(s) picked only from that side's team, and an optional table, so that I can record exactly who plays.
15. As a superuser, I want a player to be able to play several matches in one team match, so that formats like "A x Y … A x X" work.
16. As a superuser, I want to edit or delete a match inside a team match from its own card, so that I can fix a wrong lineup.
17. As a superuser, I want to score a match inside a team match with the existing "Resultados" modal, so that scoring works like any other match.
18. As a superuser, I want a "Resultado" action on the team match page that sets the team match winner, so that I can close the team match when a team reaches its win target.
19. As a visitor, I want the team match winner highlighted on its card, so that I know who won.
20. As a superuser, I want matches inside team matches on the table schedule, unscheduled pool and drag and drop, so that I can run several of them on different tables at once.
21. As a superuser, I want team matches themselves never to appear on the schedule or count as unscheduled, so that the board only holds playable matches.
22. As a superuser, I want to toggle a match inside a team match as ongoing from the schedule, so that the overview shows what's being played.
23. As a visitor, I want the overview's ongoing and next sections to show matches inside team matches with their team match context ("AABB A x Clube Y") linking to the team match page, so that I know which team match a table is playing.
24. As a visitor, I want a team match shown as ongoing once any of its matches is ongoing or has a result, and finished once it has a winner, so that the matches tab filters (all/ongoing/next) make sense for team matches.
25. As a superuser, I want to place teams in bracket slots and manage a bracket team match from its page like any other team match, advancing teams by hand as today, so that c1's knockout stage runs like a singles bracket.
26. As a visitor, I want bracket slots to show team names and the team match score, so that I can follow the knockout stage.
27. As a superuser, I want deleting a team match (or regenerating a group's matches, or deleting a stage) to delete the matches inside it, so that no orphan matches stay behind.
28. As a visitor, I want the matches tab player filter to find the team matches a player's team plays, so that I can follow a player in a team category.
29. As a visitor, I want the team match page to list each team's players, so that I know who could play.
30. As a visitor, I want a back link from the team match page to the event tab I came from, so that I can keep browsing.
31. As a visitor, I want the team match page to update live, so that I can follow results without reloading.

## Implementation Decisions

- **Vocabulary**: `GLOSSARY.md` terms Team, Team match, Match, Position, Lineup. ADR-0002 records the storage choice.
- **Category format**: `team` joins `singles` and `doubles` (label "Equipes"). Format lock rules unchanged. `Category.player_count/1` is fixed-size only; team validation uses "at least one".
- **Registration name**: new nullable `name` text column. Required for team categories, must be empty for singles/doubles (validated with the format, like the player count). Team display uses the name; singles/doubles display is unchanged.
- **Team players**: a team has ≥ 1 distinct players, no upper limit. The `registration_players` position range check (1..2) becomes "position ≥ 1" in the DB; the changeset caps positions by format (1 for singles, 1..2 for doubles, any for team). One-team-per-player-per-event+category is the existing unique index.
- **Team registration modal**: driven by the format, like doubles. Name input on top, then player + club rows starting at 3, with "add player" / remove-row controls. Stays open after adding (keeps clubs), like the other formats. `RegistrationParams.new/2` takes the starting row count for team.
- **Team match = Match**: matches generated in a team category's groups, and bracket matches of a team category's bracket stages, are team matches. No new column marks them; a team match is a match in a group/stage whose category format is `team`.
- **Matches inside a team match**: `matches.team_match_id` (self reference, `on_delete: :delete_all`). The `exactly_one_context` check becomes exactly one of `group_id`, `stage_id`, `team_match_id`. Inner matches copy `event_id`, `registration1_id`, `registration2_id` from their team match, so winner and set-winner validations are unchanged.
- **Position labels**: new nullable text columns `position1`, `position2` on matches (not the bracket `slot*_label` placeholders).
- **Match players**: new `match_players` table (match_id `on_delete: :delete_all`, side 1|2, player_id), unique (match_id, side, player_id). Players are referenced by player, not by registration player row, because editing a team replaces its rows. Singles: exactly 1 per side; doubles: exactly 2 distinct per side. The changeset rejects a player who isn't in that side's team (`registration1`/`registration2` players). The kind (singles/doubles) is implied by the player count.
- **Team match winner**: set manually through a modal with only the winner select (team 1 / team 2 / none). Inner match results never change the team match.
- **Derived values** (computed, not stored): team match score = inner match wins per team; team match status = finished if winner, ongoing if any inner match is ongoing or has a winner, else pending.
- **Standings (team category)**: `compute_group_standings` ranks by team match wins, then inner match difference, then set difference, then point difference, all from inner matches (preloaded with sets). The table gains a match-difference column for team categories (short header via gettext, implementer's choice); the name cell shows the team name.
- **Which level each view reads**:
  - Group standings, brackets, matches tab → team matches (inner matches have no group/stage, so stage/group queries already exclude them).
  - Table schedule (finished/pending per table, unscheduled pool, drag and drop, add to table, ongoing toggle, recalculation), unassigned-matches warning, matches-per-table count, overview ongoing/next → inner matches; team matches excluded. Queries that reach category/stage through `group_id`/`stage_id` reach it through the team match for inner matches.
  - Dashboard counts per category and by status: count inner matches for team categories (team matches excluded), so "games" means playable matches.
- **Team match card** (matches tab): same card shape as `match_card` (header with label, derived score; rows with team names; winner bold), rendered as a link to the team match page; no footer actions.
- **Team match page**: `T3SystemWeb.TeamMatchLive.Show` (or similar) at `/events/:id/team-matches/:team_match_id`, in the existing `:current_user` live_session. 404 when the match isn't a team match of that event. Back link to the event tab it came from (`?tab=` param). Header: category, stage/group/round label, team names, derived score, status, winner highlight; superuser actions "Adicionar partida" and "Resultado". Body: inner matches as the shared match card in creation order, each showing position labels before the players, with "Resultados" (shared score modal) and, for superusers, "Editar". Footer section: each team's players. Subscribes to the event broadcast for live updates.
- **Shared components**: `match_card` and the score modal (with its add/remove set row and save handling) move out of `event_live/show.ex` into shared components used by the event page and the team match page. Behaviour on the event page is unchanged.
- **Add/edit match modal**: fields: singles/doubles, `position1`, `position2`, player select(s) per side (options = that team's players), optional table. Edit reuses it with a delete action. Matches inside a team match are ordered by creation (id).
- **Brackets**: bracket slots show team names and the derived score; slot assignment lists teams by name; a team match's bracket card links to the team match page instead of opening the score modal. Advancing winners stays manual.
- **Card labels**: inner match cards and schedule cards are labelled with the team match context ("AABB A x Clube Y · AB x XY") and category where cards already show it. On match cards (overview, matches tab) the context links to the team match page; schedule board cards don't link.
- **Matches tab player filter**: in a team category, filtering by a player keeps the team matches where the player's team plays (or the player plays an inner match). Options list team players.
- **Live updates**: inner match changes broadcast the event like any match change.
- All new user-facing text uses `gettext`.

## Testing Decisions

- Tests check what organizers and visitors observe (page content, context accepts/rejects), not row or assign shapes.
- **Event page** (PhoenixTest, `test/t3_system_web/live/event_live/show_test.exs`, new "team category" describe): registering/editing a team; standings with team names and the tiebreak order; matches tab team match card linking to its page; overview ongoing/next showing inner matches with context; schedule listing inner matches only; bracket slots with team names linking to the page.
- **Team match page** (PhoenixTest, new `test/t3_system_web/live/team_match_live/show_test.exs`): header, score and winner highlight; adding a match with players from each team, editing/deleting it, scoring it via "Resultados", setting the winner via "Resultado"; visitors see no actions; team players listed; 404 for a non-team match.
- **Registrations context**: team requires a name and ≥ 1 distinct players; name rejected outside team categories; one team per player per event + category; more than 2 players accepted only for team.
- **Matches context**: inner match requires its players to belong to the side's team (rejects otherwise); singles 1 / doubles 2 per side; exactly-one-context check; deleting a team match deletes inner matches; derived score/status; team standings ordering (including match-difference tiebreak); schedule queries exclude team matches and include inner matches.
- **Category admin**: creating a team category.
- **Factories**: `:team_category`, `:team` (registration with name and 3 players), `:team_match` (match in a team category group), `:inner_match` (match with `team_match_id`, players per side).
- Prior art: the doubles describe in the event page tests and the registrations/matches context tests.

## Out of Scope

Everything in the map's "Not yet specified" and "Out of scope" sections: team match format templates, automatic winner/skip/advance, head-to-head tiebreaks, per-player stats, walkovers/byes specifics for teams, team size limits, lineup rules, hidden lineups, expanding team matches in place (replaced by the team match page).

## Comments
