# 08: Team matches in brackets

Status: ready-for-agent

**What to build:** A team category's bracket stage works with teams: slot assignment lists teams by name, bracket slots show team names and the derived team match score, and the bracket's "Resultados" action on a team match opens the team match winner modal (from 05) instead of the score modal. The bracket grid does not expand; matches inside bracket team matches are managed from the matches tab. Advancing winners stays manual. Spec: `.scratch/team-matches/spec.md`.

**Blocked by:** 05 (Team matches in groups and the matches tab)

- [ ] Slot assignment and slots show team names in team categories
- [ ] Derived score on bracket team matches
- [ ] Bracket "Resultados" on a team match opens the team match winner modal
- [ ] Bracket team matches appear (expandable) in the matches tab
- [ ] Event page (PhoenixTest) tests cover the above
- [ ] `mix precommit` passes

## Comments
