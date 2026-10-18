# Doubles categories

Status: ready-for-agent

## Problem Statement

Organizers run tournaments where some categories are played as doubles: two players per side, with only doubles registrations and doubles matches in that category. Today every **Registration** is a single player with a single club, so a doubles category can't be represented. Organizers have no way to register a **Pair**, show it in groups, brackets and the schedule, or record results for it.

## Solution

Every **Category** gets a **Format**: `singles` or `doubles`. A doubles category's registrations are pairs, two players who each represent their own club. A pair competes exactly like a singles registration does today: it's placed in groups and brackets, plays matches, wins sets and gets a final standing. Wherever a player's name appears today, a pair shows as "Ana / Bia" with both avatars. The schedule's player filter finds a player's matches whether they're playing singles or are one half of a pair.

## User Stories

1. As a superuser, I want to set a category's format to singles or doubles when I create it, so that the system knows how many players each registration in it has.
2. As a superuser, I want existing categories to be singles, so that past events keep working unchanged.
3. As a superuser, I want to change a category's format while no event has registrations in it, so that I can fix a mistake made when creating it.
4. As a superuser, I want a category's format to be locked once any event has registrations in it, so that existing registrations never end up with the wrong number of players.
5. As a superuser, I want the format picker to show why it is locked, so that I understand why I can't change it.
6. As a superuser, I want the "add registration" modal for a doubles category to ask for two players, each with their own club, so that I can register a pair in one step.
7. As a superuser, I want the "add registration" modal for a singles category to stay as it is today, so that registering singles players isn't slowed down.
8. As a superuser, I want the doubles modal to stay open after adding a pair, keeping both club selections, so that I can quickly register several pairs from the same clubs.
9. As a superuser, I want the player pickers to hide players already registered in that event + category, in either position of any pair, so that I can't register someone twice.
10. As a superuser, I want the second player picker to hide the player chosen in the first, so that I can't pair a player with themselves.
11. As a superuser, I want a clear error if I try to save a doubles registration with only one player, so that incomplete pairs can't be created.
12. As a superuser, I want a clear error if a player is already in another registration of the same event + category, so that the uniqueness rule holds even if two people register at the same time.
13. As a superuser, I want to register the same player in a singles category and a doubles category of the same event, so that players can enter both.
14. As a superuser, I want to pair players from different clubs, so that partnerships across clubs are represented accurately.
15. As a superuser, I want any two different players to be able to form a pair, with no gender or age checks, so that mixed, men's and women's doubles are defined just by the category name.
16. As a superuser, I want to edit a pair's players and clubs at any time, so that I can swap in a substitute partner.
17. As a superuser, I want results already recorded for a pair to stay with the pair after I edit its players, so that substitutions don't erase match history.
18. As a superuser, I want to delete a doubles registration the same way as a singles one, so that managing registrations works the same in both formats.
19. As a superuser, I want to set a final standing on a doubles registration, so that a pair's placement is recorded once for both players.
20. As a superuser, I want to add pairs to groups and brackets the same way as singles registrations, so that running a doubles draw works like a singles one.
21. As a superuser, I want to record set scores and winners for doubles matches the same way as singles, so that scoring works identically.
22. As a superuser, I want to schedule doubles matches on tables alongside singles matches, so that one event schedule covers every category.
23. As a visitor, I want to see doubles registrations as "Ana / Bia" with both players' avatars, so that I can tell who makes up each pair.
24. As a visitor, I want to see each partner's club on the registration cards, so that I know who each player represents.
25. As a visitor, I want pairs shown as "Ana / Bia" in group tables, so that I can follow group standings in doubles.
26. As a visitor, I want pairs shown as "Ana / Bia" in the bracket, so that I can follow the knockout stage in doubles.
27. As a visitor, I want pairs shown as "Ana / Bia" on schedule match cards, including the winner highlight, so that I know which pair won.
28. As a visitor, I want to filter the schedule by a player and see both their singles matches and their doubles matches, so that I can follow everything that player is playing.
29. As a visitor, I want the schedule's player filter to list every player in every pair, so that I can find any partner, not just the first one entered.
30. As a visitor, I want a pair's players always shown in the same order, so that the display is consistent across the page.
31. As a visitor, I want the final standing (gold/silver highlight) shown for pairs the same way as for singles players, so that doubles podiums are visible.
32. As a superuser, I want the "registration added" confirmation to name both players of a pair, so that I can confirm the right pair was saved.

## Implementation Decisions

- **Domain vocabulary** follows `GLOSSARY.md`: Category, Format, Registration, Pair. The architectural choice is recorded in `docs/adr/0001-registration-players-as-a-list.md`.
- **Category format:** a named text value, `singles` or `doubles`, required, defaulting to `singles`. It's stored as a named value rather than a yes/no flag so that `team` can be added later as another value. The categories context refuses a format change when any registration exists for that category, and the admin category form disables the picker in that case.
- **Registration players:** a new child record of a registration, one row per player, holding the player, that player's club, and a position (1 or 2) used only for display order. The row also stores the registration's event and category, so the database can enforce one row per (player, event, category). That is the rule "a player appears at most once in an event + category, in any position". A unique rule on (registration, position) prevents duplicate positions.
- **Registration schema:** the player and club columns move off the registration and into the registration-player rows. The registration keeps event, category and final standing, plus its existing links to groups and matches. The old unique rule on (player, event, category) is replaced by the one on the player rows.
- **Data migration:** each existing registration becomes one registration-player row (position 1) with its current player and club, after which the old columns are dropped. All existing categories get format `singles`.
- **Registration validation:** a registration takes its players as nested input. The number of players must match the category's format: exactly 1 for singles, exactly 2 for doubles. The two players of a pair must be different. A database uniqueness violation shows up as a validation error on the offending player.
- **Registrations context:** create, update and delete keep their current superuser-only signatures and take the nested players. Editing replaces the player list. The lookup of "player ids already registered in this event + category" returns every player in any position. Loading a registration preloads its players in position order, each with player and club.
- **Matches and scheduling:** no structural change. Groups, brackets, matches, sets, winners and final standing still refer to registrations. Queries that preload a match's registrations preload their ordered players instead of a single player and club.
- **Display component:** a shared function component takes a list of players (each with name, picture and club) and renders the names joined by " / ", overlapping avatars, and clubs where the calling context shows clubs. It takes players rather than a registration so that pairs that aren't registrations (doubles games inside a future team tie) can reuse it. Every place that renders a registration's player name, avatar or club switches to it: registration cards, group tables, bracket slots, schedule match cards, winner highlights, the group-management picker labels, and flash messages.
- **Registration modal:** driven by the selected category's format. Singles shows one player + club row, unchanged. Doubles shows two rows. After a successful add, the modal stays open and keeps the club selection(s). Each player picker hides players already registered in the category, and the second picker also hides the first row's selection.
- **Schedule player filter:** each match card holds the set of player ids on each side. Filtering by a player matches a card if that player is on either side. The filter's options list every player of every registration in the event, without duplicates.
- All new user-facing text goes through `gettext`.

## Testing Decisions

- Good tests here check behaviour the organizer or visitor can observe (what the page shows, what the context accepts or rejects) and never the internal shape of rows, preloads or assigns.
- **Event page** (PhoenixTest, the existing event page LiveView test file): the main seam. It covers:
  - adding a pair through the doubles modal and seeing "Ana / Bia" on the registration card;
  - the doubles modal staying open with both clubs kept;
  - the pickers hiding already-registered players and the first selection;
  - editing a pair's partner;
  - pairs rendering in group tables, the bracket and schedule cards, including the winner and final-standing highlight;
  - the player filter showing a player's doubles matches when they're in position 2;
  - the singles flows still behaving exactly as they do today.
- **Registrations context** (the existing registrations context test file): the edge-case rules.
  - The player count must match the format: 0 or 2 players rejected for singles, 1 or 3 rejected for doubles.
  - The same player twice in one pair is rejected.
  - A player already in another registration of the same event + category is rejected, in either position.
  - The same player in a singles and a doubles category of one event is accepted.
  - Editing replaces the players.
  - The "registered player ids" lookup includes partners.
  - Non-superusers can't create a registration (existing pattern).
- **Category admin page** (the existing category LiveView test file): creating a doubles category, changing the format while there are no registrations, and the format being locked once one exists.
- **Factories:** the registration factory builds one registration-player row by default (singles). A doubles variant builds a doubles category and two player rows with different players and clubs. Existing tests that pass `player:`/`club:` to the registration factory are updated to the new shape, which covers the migration indirectly.
- Prior art: the event page tests already cover registration cards, the add/edit/delete modal (including "keeps modal open with club selected"), group management and the schedule filter. Follow those patterns, with `insert/2` factories and PhoenixTest `visit`/`fill_in`/`click_button`/`assert_has`.

## Out of Scope

- Team events (team ties made up of singles and doubles games with an aggregate result). The design only leaves room for them: a format value, registrations with N players, and a display component built from players.
- Warnings when a player is scheduled at two tables at the same time (e.g. a singles and a doubles match together).
- Gender or age rules for who may form a pair.
- Per-player rankings or league points across events.
- A captain or primary player within a pair. Position is only for display order.

## Further Notes

- The format lock is checked against registrations in any event, since categories are shared across events.
- Doubles uses the event's current match duration, the same as singles.

## Comments
