# 05: Edit and delete a pair

**What to build:** A superuser can open the edit modal for a doubles registration, swap either partner (e.g. a substitute) or change either partner's club, and save. The same uniqueness and different-players rules apply. Editing replaces the pair's players, while matches, set results, group membership and final standing stay with the registration. Deleting a doubles registration works the same as a singles one. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** 04 (Register a pair in a doubles category)

**Status:** resolved

- [x] The edit modal for a doubles registration shows both players and clubs pre-filled
- [x] Swapping a partner or changing a club saves, and the card shows the updated pair
- [x] Editing respects the uniqueness and different-players rules
- [x] Recorded match results, group membership and final standing stay with the pair after an edit
- [x] Deleting a doubles registration removes it from the page
- [x] Context and event page tests cover the above
- [x] `mix precommit` passes

## Comments
