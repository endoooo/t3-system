# 03: Categories have a singles/doubles format

**What to build:** Every Category has a Format, `singles` or `doubles`. It's stored as a named value, not a yes/no flag, so `team` can be added later. It's required, defaults to `singles`, and existing categories are migrated to `singles`. In the admin category form, a superuser picks the format when creating a category and can change it while no event has registrations in that category. Once any registration exists for the category, in any event, the context refuses a format change and the form shows the picker disabled with an explanation. Spec: `.scratch/doubles/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Categories have a required format, `singles` or `doubles`, defaulting to `singles`. Existing categories are `singles`
- [x] A superuser can create a doubles category from the admin page
- [x] The format can be changed while the category has no registrations in any event
- [x] Once the category has a registration, the context rejects a format change and the admin form shows the picker locked with an explanation (gettext)
- [x] Category admin LiveView tests and categories context tests cover the above
- [x] `mix precommit` passes

## Comments
