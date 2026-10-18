# 02: Store a registration's players as a list

**What to build:** A prefactor with no visible change. A Registration's players move from the player and club columns on the registration into registration-player rows: player, that player's club, a position (display order only), and the registration's event and category. The database enforces one row per (player, event, category) and one row per (registration, position). Each existing registration is migrated into one row at position 1, then the old columns and the old (player, event, category) unique rule are dropped. Registrations take their players as nested input. Loading a registration preloads its players in position order, each with player and club. Match and group preloads load the ordered players. The "registered player ids for an event + category" lookup returns players in any position. The existing single-player modal saves through the new shape, the display component from 01 is fed from the player list, and the schedule player filter matches against the set of player ids on each side. The registration factory builds one player row by default. See `docs/adr/0001-registration-players-as-a-list.md` and `.scratch/doubles/spec.md`.

**Blocked by:** 01 (Show a registration's players through one shared display component)

**Status:** resolved

- [x] Migration creates the registration-player rows from existing registrations with no data loss, then drops the old player and club columns
- [x] The database rejects the same player twice in one event + category, and two rows with the same position in one registration
- [x] Registrations are created and updated with nested players. A uniqueness violation shows as a validation error on the offending player
- [x] Registrations, matches and groups preload ordered players with player and club
- [x] The registered-player-ids lookup returns every player in any position
- [x] The schedule player filter matches a player on either side by the set of player ids on that side
- [x] Factory updated. Existing tests pass, including the singles add/edit/delete modal flows
- [x] `mix precommit` passes

## Comments
