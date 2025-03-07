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

## Corridors

The original corridor generation is kind of C-squirrelly that I'd have to see
in action, and has been distilled to an S-shape formed by traveling either
South or East as the primary digging direction and an orthogonal adjustment at
the midpoint.

## "Gone" rooms

The map generator will occasionally render a 1x1 'gone' room that can act
as either a junction or a long corridor between non-adjacent rooms.

## Maze rooms

The original is more code that has to be stepped through, but I think the
essence is that the room location becomes a warren of corridors.

## Rooms

You can't have rooms on the top line of the display, which provides messages.

In the original, where the map and display are lined up 1:1, this means that
mapgen has to avoid y==0.  Which it does by retrying room placements until it
succeeds.  It eventually will but this is a little weird to see.

Here, there is no such mapping.  The map is truncated to fit the allowed space.
