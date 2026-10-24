# 05: Team matches in groups and the matches tab

Status: ready-for-agent

**What to build:** In a team category, the matches generated for a group are team matches (no schema change: a match in a team category's group/stage). Group standings show team names. The matches tab shows team match cards, same shape as `match_card`, with team names, the derived score (inner match wins, 0 — 0 until 06 lands) and the winner highlighted; clicking the card body expands it in place (empty list for now). Superuser footer: "Resultado" opens a modal with only the team match winner select (team 1 / team 2 / none); "Adicionar partida" comes in 06. Team match status is derived (finished with a winner; ongoing/pending from inner matches) and drives the all/ongoing/next filter. The player filter keeps team matches where the player's team plays. Spec: `.scratch/team-matches/spec.md`.

**Blocked by:** 04 (Team categories and team registrations)

- [ ] Group standings list teams by name in team categories
- [ ] Matches tab renders team match cards with derived score and winner highlight, expandable in place
- [ ] "Resultado" footer action sets/clears the team match winner (superuser only)
- [ ] Derived status used by the all/ongoing/next filter; player filter by team membership
- [ ] Factory `:team_match`
- [ ] Event page (PhoenixTest) and matches context tests cover the above
- [ ] `mix precommit` passes

## Comments
