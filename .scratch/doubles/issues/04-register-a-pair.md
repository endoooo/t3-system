# 04: Register a pair in a doubles category

**What to build:** When the selected category is doubles, the "add registration" modal on the event page asks for two player + club rows. After a successful add it stays open for the next pair and keeps both club selections. Each player picker hides players already registered in that event + category in any position, and the second picker also hides the first row's choice. The registrations context requires the number of players to match the category's format (exactly 1 for singles, exactly 2 for doubles) and the two players of a pair to be different. Any two different players can form a pair, from the same or different clubs, with no gender or age checks. The same player can still enter a singles category and a doubles category in the same event. Registration cards show the pair as "Ana / Bia" with both avatars and each partner's club, and the "registration added" flash names both players. Singles registration is unchanged. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** 02 (Store a registration's players as a list), 03 (Categories have a singles/doubles format)

**Status:** ready-for-agent

- [ ] The modal shows two player + club rows for a doubles category and one row for singles
- [ ] After adding a pair, the modal stays open with both clubs kept
- [ ] Pickers hide players already registered in the event + category (either position), and the second picker hides the first row's choice
- [ ] The context rejects 0 or 2 players for singles, 1 or 3 for doubles, and the same player twice in one pair, with a clear error
- [ ] The context rejects a player already in another registration of the same event + category, in either position
- [ ] The same player can be registered in a singles and a doubles category of one event
- [ ] Registration cards show "Ana / Bia" with both avatars and each partner's club. The flash names both players
- [ ] Registrations context tests and event page (PhoenixTest) tests cover the above. A doubles factory variant exists
- [ ] `mix precommit` passes

## Comments
