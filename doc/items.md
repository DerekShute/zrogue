# Items

## Gold

The original implementation is kind of squirrelly.  Gold is an item placed
during room generation where the implementation is incestuous with the room
itself: the amount of gold and the position of the gold item are fields within
the room.

Implication: you can't drop gold, and gold can't exist outside of the room.
