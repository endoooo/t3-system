# Team match overlay and admin flow

Type: prototype
Status: resolved
Blocked by: 01

## Question

What does clicking a team match show (visitors and superusers), and how does a superuser add, edit and score the singles/doubles matches inside it (pick each side's players from the teams, set position labels, schedule to a table, set the team match winner)?

## Answer

Prototype: branch `prototype/team-match-overlay` (commit "prototype(team-matches): team match overlay and admin flow variants"), route `/dev/prototype/team-match?variant=A|B|C`. Variants: A modal list, B scoresheet drawer, C expand in place.

Verdict: **C, expand in place**, with the team match card's own controls moved into a footer like the individual match card's.

- **Team match card**: same card shape as a match card (header with round label and derived score "2 — 1", one row per team with its match wins). Clicking it expands it in place; no overlay. Rejected A because it stacks a modal over a modal (match form/score modal on top of the team match modal); rejected B because it doesn't reuse the existing match cards.
- **Expanded content**: the matches inside it rendered as the **existing match cards**, each showing its position labels ("AB" / "XY") next to its players, sets, table/time and ongoing dot. Each keeps its existing superuser "Resultados" action (existing score modal, unchanged).
- **Team match card footer (superuser)**, following the match card footer: **"Adicionar partida"** (opens a modal: singles/doubles, position label per side, each side's players picked from that side's team only, optional table) and **"Resultado"** (opens a modal with only the team match winner select). Editing/deleting an inner match is reached from its own card (an "Editar" action next to "Resultados", same modal as adding).
- **Visitors**: same expand-in-place view, no footer actions.
- Applies wherever team matches are listed (group view, bracket, matches tab); the bracket's compact slots may only need the expand on click, decided in the spec.

### Amendment (2026-10-24): team match detail page

Expanding in place doesn't work in the bracket grid, so it is replaced by a **team match detail page** used from both the matches tab and the bracket:

- Route `/events/:id/team-matches/:team_match_id`, in the `:current_user` live_session; visitors read-only, superusers get actions.
- Page: back link to the event tab it came from; header with category, stage/group/round label, team names, derived score, status and winner highlight; the inner matches as the existing match cards (position labels, players, sets, table/time, ongoing), in creation order; each team's players at the bottom.
- Actions all live on the page: "Adicionar partida" and "Resultado" (team match winner) in the header; each inner match card keeps "Resultados" and gains "Editar".
- The matches tab team match card and the bracket slot are plain links to the page (no footer actions, no expansion).
- The team match context label on inner match cards (overview ongoing/next, matches tab) links to the page; schedule board cards stay unchanged.
- The match card and the score modal are extracted from `event_live/show.ex` into shared components so both pages use them.
- Still valid from the verdict above: reuse of the existing match cards for inner matches, the add/edit match modal fields, visitors without actions.
