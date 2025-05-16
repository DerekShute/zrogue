# Level Generation

## General rules

Rogue traditionally has a simple map layout: rooms are fundamentally in a 3x3
grid, and everything (including message lines) must fit into a VT100 standard
80x24 display.

Rooms only have adjacent connections.

The map generator is careful to ensure that all rooms are reachable.

In the original code the algorithm is theoretically generic but you will see
"3" and "9" hardcoded everywhere and arrays with those assumptions, so good
luck changing the basal MAXROOMS and so forth.

The level starts as a grid of wall tiles and mapgen carves rooms and corridors
from it.

## Corridors

The original corridor generation is kind of C-squirrelly that I'd have to see
in action, and has been distilled to an S-shape formed by traveling either
South or East as the primary digging direction and an orthogonal adjustment at
the midpoint.

Corridors are floor tiles surrounded by wall.  This will probably make magic-
mapping interesting.

## "Gone" rooms

The map generator will occasionally render a 1x1 'gone' room that can act
as either a junction or a long corridor between non-adjacent rooms.

These are now 3x3 rooms because corridors are not special tiles surrounded by
void.

Stairs can appear in a gone room.  Why not?

## Maze rooms

The original is more code that has to be stepped through, but I think the
essence is that the room location becomes a warren of corridors.

We don't do this for 0.1

## Rooms

You can't have rooms on the top line of the display, which provides messages.

In the original, where the map and display are lined up 1:1, this means that
mapgen has to avoid y==0.  Which it does by retrying room placements until it
succeeds.  It eventually will but this is a little weird to see.

Here, there is no such mapping.  The map is truncated to fit the allowed space.

## Code coverage

There's a test level generator that does fixed design.  This was planned for
kcov work.
