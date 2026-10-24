# A team match is a match that wraps matches

Team categories need a team match (team against team) made of singles and doubles matches between their players. We store both levels as `Match` rows: the team match is an ordinary match between the two team registrations, living in a group or bracket stage like any other, and each match inside it is a match that points to its team match instead of to a group or stage. Inner matches keep the two team registrations as their sides, so winners, set winners, scoring, tables, the ongoing flag and live updates work unchanged; who actually plays each side is a separate list of that team's players, plus a free position label ("AB", "XY"). The team match is a thin wrapper: its winner is set by hand, its score is counted from the inner matches, and it never goes on a table itself.

## Considered Options

- **A separate TeamMatch entity that groups and brackets point to**: would rewrite groups, brackets and standings for one category format, the same cost ADR-0001 avoided for pairs.
- **Team match as a Match, games in their own table**: would duplicate sets, scoring and the table schedule for the games.

## Consequences

- A match belongs to exactly one of a group, a bracket stage or a team match.
- Queries must pick the right level: groups, brackets and the matches tab read team matches; the table schedule and the ongoing/next sections read the matches inside them.
- Deleting a team match (or regenerating a group) deletes the matches inside it.
