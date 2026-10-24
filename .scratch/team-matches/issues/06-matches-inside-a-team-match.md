# 06: Matches inside a team match

Status: resolved

**What to build:** Matches can belong to a team match: `matches.team_match_id` (self reference, cascade delete), `exactly_one_context` becomes one of group/stage/team match, new `position1`/`position2` text columns, and a `match_players` table (match, side 1|2, player) with unique (match, side, player). Inner matches copy event and both team registrations from their team match. Singles = 1 player per side, doubles = 2 distinct per side; each side's players must belong to that side's team (changeset error otherwise); a player may play several matches of one team match. First, extract `match_card` and the score modal (with its set-row and save handling) from `event_live/show.ex` into shared components, leaving the event page's behaviour unchanged. On the team match page, a superuser "Adicionar partida" header action opens a modal (singles/doubles, position label per side, player select(s) per side limited to that team, optional table); inner matches render in creation order as the shared match card with position labels before the players, keep "Resultados" (shared score modal) and gain "Editar" (same modal, with delete). The derived team match score and status now count inner matches. Team group standings rank by team match wins → inner match difference → set difference → point difference, with a match-difference column. Deleting a team match, regenerating a group or deleting a stage removes inner matches. Spec: `.scratch/team-matches/spec.md`.

**Blocked by:** 05 (Team matches in groups and the matches tab)

- [ ] Shared match card and score modal extracted; event page unchanged (its tests still pass)
- [ ] Migration: `team_match_id`, context check, `position1`/`position2`, `match_players`
- [ ] Inner match validation: players per side by kind, players belong to the side's team
- [ ] Add/edit/delete inner matches from the team match page (superuser); visitors see them read-only
- [ ] Inner matches scored through the existing "Resultados" modal
- [ ] Derived score/status count inner matches; standings tiebreak order and match-difference column
- [ ] Cascade deletes (team match, group regeneration, stage)
- [ ] Factory `:inner_match`
- [ ] Matches context and team match page (PhoenixTest) tests cover the above
- [ ] `mix precommit` passes

## Comments
