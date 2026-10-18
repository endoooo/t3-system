# 01: Show a registration's players through one shared display component

**What to build:** A prefactor with no visible change. Add a shared function component that takes a list of players (name, picture, club) and renders the names joined by " / ", overlapping avatars, and the clubs when the caller asks for them. Switch every place on the event page that shows a registration's player name, avatar or club to this component: registration cards, group tables, bracket slots, schedule match cards, winner and final-standing highlights, group-management picker labels, and flash messages. For now each caller passes a one-player list built from the registration's single player and club. The component takes players, not a registration, so pairs that aren't registrations (games inside a future team tie) can reuse it (see `docs/adr/0001-registration-players-as-a-list.md`). Spec: `.scratch/doubles/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] One shared component renders a list of players: names joined by " / ", overlapping avatars, and optional clubs
- [x] Every place that showed a registration's player name, avatar or club uses the component
- [x] Event page output for singles registrations is unchanged
- [x] Existing event page tests pass without changes to their assertions
- [x] `mix precommit` passes

## Comments
