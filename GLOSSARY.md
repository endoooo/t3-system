# T3 System

Runs table tennis tournaments: events, the categories played in them, who registered, and the matches between them.

## Language

**Category**:
A division of play (e.g. "Livre", "Duplas Livre") that can be offered across many events. Every category has a single format.
_Avoid_: Division, class

**Format**:
Whether a category is played as singles (one player per side) or doubles (two players per side).
_Avoid_: Mode, type

**Registration**:
One entrant in one category of one event: a single player in singles, or a pair in doubles. Registrations, not players, are what compete in matches.
_Avoid_: Entry, inscription, competitor

**Pair**:
Two players playing together on one side of a doubles game. A doubles registration consists of a pair, and each player in a pair represents their own club.
_Avoid_: Team, duo, partnership
