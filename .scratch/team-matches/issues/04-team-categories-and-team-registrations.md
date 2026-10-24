# 04: Team categories and team registrations

Status: ready-for-agent

**What to build:** A Category can have the `team` format ("Equipes"). Its registrations are Teams: a required `name` and one or more distinct players, each with their club, no upper limit. Registrations get a nullable `name` column, required for team and rejected for singles/doubles. The `registration_players` position check becomes "≥ 1" in the DB, with the changeset capping positions by format. The event page's registration modal, for a team category, shows a name input and player + club rows (starting at 3) with add/remove-row controls; it stays open after adding, like the other formats, and edits work the same way. Registration cards in a team category show the team name with players and clubs below. Spec: `.scratch/team-matches/spec.md`.

**Blocked by:** None (can start immediately)

- [ ] `team` format selectable in the admin category form; format lock unchanged
- [ ] Registration `name` column; required for team, rejected for singles/doubles
- [ ] Team validation: ≥ 1 distinct players, any count; position range lifted for team only
- [ ] Team registration modal: name, 3 starting rows, add/remove rows, stays open keeping clubs; editing a team
- [ ] Registration cards show team name + players/clubs
- [ ] Factories `:team_category`, `:team`
- [ ] Registrations context, category admin and event page (PhoenixTest) tests cover the above
- [ ] `mix precommit` passes

## Comments
