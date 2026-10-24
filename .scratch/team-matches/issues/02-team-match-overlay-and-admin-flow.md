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
