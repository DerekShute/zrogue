# Level Generation

## General rules

Rogue traditionally has a simple map layout: rooms are fundamentally in a 3x3
grid, and everything (including message lines) must fit into a VT100 standard
80x24 display.

Rooms only have adjacent connections.

The map generator is careful to ensure that all rooms are reachable.

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