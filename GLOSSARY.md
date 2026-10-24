# T3 System

Runs table tennis tournaments: events, the categories played in them, who registered, and the matches between them.

## Language

**Category**:
A division of play (e.g. "Livre", "Duplas Livre") that can be offered across many events. Every category has a single format.
_Avoid_: Division, class

**Format**:
Whether a category is played as singles (one player per side), doubles (two players per side) or team (a team per side, playing team matches).
_Avoid_: Mode, type

**Registration**:
One entrant in one category of one event: a single player in singles, a pair in doubles, or a team in a team category. Registrations, not players, are what compete in matches.
_Avoid_: Entry, inscription, competitor

**Pair**:
Two players playing together on one side of a doubles game. A doubles registration consists of a pair, and each player in a pair represents their own club.
_Avoid_: Team, duo, partnership

**Match**:
One side against the other, decided in sets: a singles or a doubles game. In a team category, the matches are played inside team matches.
_Avoid_: Rubber, game

### Team play

**Team**:
A registration in a team category: a named squad of players who represent it.
_Avoid_: Squad, club

**Team match**:
One team against another: a wrapper around the matches the two teams play against each other. In a team category, team matches are what groups and brackets are made of.
_Avoid_: Tie, encounter, confronto

**Team match format**:
The ordered list of matches a team match is made of, written in positions (e.g. "AB x XY, C x Z, A x X"), and how many match wins decide it.
_Avoid_: Team format, system

**Position**:
A free label naming who plays each side of a match inside a team match, by the team's chosen letters (e.g. "AB" against "XY", "C" against "Z").
_Avoid_: Slot, seat

**Lineup**:
Which of its players a team puts in each position for one team match.
_Avoid_: Escalação, roster
