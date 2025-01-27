const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const zrogue = @import("zrogue.zig");
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;

const level = @import("level.zig");
const Thing = @import("thing.zig").Thing;
const MessageLog = @import("message_log.zig").MessageLog;

pub fn run(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !void {
    const map = try level.Map.init(allocator, zrogue.MAPSIZE_Y, zrogue.MAPSIZE_X);
    defer map.deinit();

    const msglog = try MessageLog.init(allocator);
    errdefer msglog.deinit();

    // TODO: player as input to the run
    var player = Thing.config(
        10,
        10,
        '@',
        input,
        display,
        playerAction,
        msglog,
    );

    try map.setMonster(&player, 10, 10);
    try display.erase();

    try map.drawRoom(5, 5, 15, 15);
    player.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy
    var action = ThingAction.init(ActionType.NoAction);
    while (action.type != ActionType.QuitAction) {
        action = try player.doAction(map);
        switch (action.type) {
            ActionType.QuitAction => continue, // TODO: 'quitting' message
            ActionType.BumpAction => try bumpAction(&player, &action, map),
            ActionType.NoAction => continue,
        }
    }
}

//
// Player action development here
//

fn bumpAction(entity: *Thing, do_action: *ThingAction, map: *level.Map) !void {
    const pos = entity.getPos();

    const new_x = pos.getX() + do_action.pos.getX();
    const new_y = pos.getY() + do_action.pos.getY();

    if (try map.getChar(new_x, new_y) == '.') { // TODO manifest constant
        try map.removeMonster(pos.getX(), pos.getY());
        try map.setMonster(entity, new_x, new_y);
        // TODO reveal surroundings if dark and not blind
    } else {
        entity.addMessage("Ouch!");
    }
}

//
// Map is the _visible_ or _known_ map presented to the player
//
fn playerAction(self: *Thing, map: *level.Map) !ThingAction {
    var ret = ThingAction.init(ActionType.NoAction);

    const message = self.getMessage();

    for (0..zrogue.MAPSIZE_X) |x| {
        if (x < message.len) {
            try self.display.mvaddch(@intCast(x), 0, message[x]);
        } else {
            try self.display.mvaddch(@intCast(x), 0, ' ');
        }
    }

    self.clearMessage();

    //
    // Convert map to display: it shifts down one row to make room for
    // messages
    //
    // TODO: the actual character is display-dependent.  All this should use constants
    // to describe what the place is:  floor, door, wall/solid, etc.
    //
    for (0..zrogue.MAPSIZE_Y) |y| {
        for (0..zrogue.MAPSIZE_X) |x| {
            const c = try map.getChar(@intCast(x), @intCast(y));
            try self.display.mvaddch(@intCast(x), @intCast(y + 1), c);
        }
    }

    // TODO law of demeter
    try self.display.refresh();
    const ch = try self.input.getch();

    switch (ch) {
        'q' => ret = ThingAction.init(ActionType.QuitAction),
        'l' => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(-1, 0)),
        'r' => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(1, 0)),
        else => try self.display.mvaddch(0, 0, @intCast(ch)),
    }

    return ret;
}

// EOF
