# 05: Edit and delete a pair

**What to build:** A superuser can open the edit modal for a doubles registration, swap either partner (e.g. a substitute) or change either partner's club, and save. The same uniqueness and different-players rules apply. Editing replaces the pair's players, while matches, set results, group membership and final standing stay with the registration. Deleting a doubles registration works the same as a singles one. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** 04 (Register a pair in a doubles category)

**Status:** ready-for-agent

- [ ] The edit modal for a doubles registration shows both players and clubs pre-filled
- [ ] Swapping a partner or changing a club saves, and the card shows the updated pair
- [ ] Editing respects the uniqueness and different-players rules
- [ ] Recorded match results, group membership and final standing stay with the pair after an edit
- [ ] Deleting a doubles registration removes it from the page
- [ ] Context and event page tests cover the above
- [ ] `mix precommit` passes

## Comments
