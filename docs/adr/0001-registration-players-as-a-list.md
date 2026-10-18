# A registration holds a list of players

Doubles categories need a registration to be a pair, not a single player. We keep the registration as the one thing that competes in groups, brackets and matches, and store its players as a list (one row per player, each with their own club and a display order) instead of adding partner columns or a separate Pair/Team entity. A list covers singles (one player) and doubles (two), and it will also cover the squads of the team events planned next without reshaping registrations again. It also lets the database enforce "a player appears at most once per event and category" across every slot.

## Considered Options

- **Partner columns next to `player_id`**: the smallest change for doubles, but capped at two players, so team events would mean redoing every registration, uniqueness check and name display a second time.
- **A separate Pair/Team entity that matches point to**: would change groups, brackets, matches and sets, all of which already work in terms of registrations.

## Consequences

- Category gets a named format (`singles`, `doubles`, and `team` later) that decides how many players a registration holds.
- Player display (names, avatars, clubs) is built from a list of players, not from a registration, so the doubles games inside a future team tie, whose pairs aren't registrations, can reuse it.
