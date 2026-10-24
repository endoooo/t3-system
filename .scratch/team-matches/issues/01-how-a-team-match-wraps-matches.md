# How a team match wraps matches

Type: grilling
Status: resolved

## Question

How is a team match stored and how do the matches inside it relate to it, given groups, brackets, standings, the table schedule and set scoring all work in terms of `Match` between two registrations today?

Covers: whether a team match is a `Match` row (with child matches) or its own table; how a match inside a team match records each side's players (1 or 2 team players) and position labels; how the "players belong to the side's team" rule is enforced; what changes in `Category` (team format) and `RegistrationPlayer` (position capped at 2 today); how group standings and the derived team match score read the inner matches; which existing queries (schedule, ongoing/next, matches tab, counts) must include or exclude which kind of match.

## Answer

Recorded in ADR-0002 (`docs/adr/0002-team-match-is-a-match-wrapping-matches.md`).

- **Storage**: a team match is an ordinary `Match` between the two team registrations, in a group or bracket stage. Matches inside it are `Match` rows with a `team_match_id`; the `exactly_one_context` check becomes "exactly one of group, stage, team match". Inner matches carry `event_id` too.
- **Sides**: inner matches keep the team registrations as `registration1`/`registration2` (winner and set-winner checks unchanged). Who plays is a new list of match players (match, side 1|2, a player of that side's team), 1 or 2 per side; the changeset rejects a player not in that side's team. A player may appear in several matches of one team match.
- **Position labels**: new `position1`/`position2` free-text fields on the match (not the bracket `slot*_label` placeholders).
- **Team name**: registrations get a `name`, required in team categories, absent in singles/doubles. Cards, standings and brackets show the team name; the overlay and inner matches show players.
- **Category / registration**: category format gains `team`; a team has at least one player, no upper limit (the `registration_players` position 1..2 range applies to singles/doubles only). One team per player per event + category is already enforced.
- **Winner and score**: team match winner set manually; displayed score is the count of inner match wins. Inner match results never change the team match automatically.
- **Status**: a team match never goes on a table. Pending until any inner match is ongoing or has a result, then ongoing, finished when it has a winner.
- **Standings (team categories)**: rank by team match wins, then inner match difference, then set difference, then point difference, all read from the inner matches.
- **Which level each view reads**: groups, brackets, matches tab → team matches. Table schedule (scheduled, unscheduled pool, drag and drop, add to table, ongoing toggle), overview ongoing/next → inner matches. Unscheduled queries reach category/stage through the team match. Dashboard counts stay fog.
- **Deleting**: cascades from a team match to its matches; regenerating a group wipes them, as it wipes scores today.
