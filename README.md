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

## Package Dependencies

### Whatever the zig snap provides

### graphviz (version unspecified)

For visualization

### kublkon/zig-yaml

For structured configuration and data files via YAML

### Hejsil/zig-clap

For command-line goodness

## Releases

### 0.2 (forward looking)

With a basic engine we can talk about repositioning it for Webassembly or
some clever webservice prop-up (umoria has this and it is awesome) and for
client-server and multiplayer.

I don't care about Windows binaries.

Also need to consider issues around serialization and if Lua integration
makes sense / sounds fun.

Traps?  Probably necessary to intrude randomization into the action callback

Food?  Implies timers, possibly inventory, statuses

Refactoring?  Making the modules more Zig-idiomatic.  My C roots are showing.

Test Rig: more rigorous "take action, validate expectations" framework

### 0.1 - Run around the dungeon and collect gold

A basic 4 level dungeon with no traps or monsters or Amulet of Yendor but
pieces of gold and hidden doors.  Get to the bottom and come back up and
you will be graded appropriately to the high score list.

Works on Linux with ncurses and nowhere else.

Map generation is _mostly_ rogue with a few tweaks.

# Internal Documentation
  * [Gameplay!](/docs/gameplay.md)
  * [Implementation Details](/docs/implementation.md)
  * [Items](/docs/items.md)
  * [Levels](/docs/levels.md)

# What, you want to use this?

Color me shocked!  Shocked and flattered!

I'm only interested in it running from Ubuntu 22.04+ and this only from PuTTY
from Windows, because that's my admittedly primitive/awful operating
environment.  Other use might run into keypress-translation issues and ncurses
support.

In terms of what I think is necessary to get it going, from Ubuntu

libncurses-dev gcc g++

and I use the zig snap as documented.
