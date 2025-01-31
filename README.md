# Learning Zig the hard way by porting Rogue

## Goals

Proficiency in Ziglang, which is turning out to be an interesting journey.

This may never beome a finished product; if I learn as much as this exercise
will teach me then it will very readily get kicked to the curb.

The goal is not a 1:1 replication of the original, which intertwines the
interface with the behavioral logic and assumes a single-player environment,
and I really want this to be the basis of something more flexible, separating
the front-end (interface) from the game logic and arbitration (engine),
allowing multiple implementations and even possibly a multi-user experience.

And part of this is figuring out why certain things about the original
implementation are the way they are--why is THING (literally) a union mashing
together monster and object/gear characteristics?

   (spoiler: I think it was so that the list management is consolidated)

## Reference points

"Canonical" Rogue behavior given by:

   https://github.com/Davidslv/rogue/

And my own feeble Python effort:

   https://github.com/DerekShute/PyRogue/

Which started from the very instructive v2 TCOD tutorial:

   https://rogueliketutorials.com/tutorials/tcod/v2/

## Visualization

Mostly an experiment.  Generates visualize.svg, which is a directed graph
showing relationships between structures.

This is all propped up using formatted comments, manually inserted, which is
almost certainly going to become out of date the second I lose interest.

If this is useful then I can experiment with control flow visualization.
