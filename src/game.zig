const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const zrogue = @import("zrogue.zig");
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;

const level = @import("level.zig");
const Thing = @import("thing.zig").Thing;

// TODO: test maxx, maxy
pub fn run(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !void {
    const map = try level.Map.init(allocator, 24, 80);
    var player = Thing.config(10, 10, '@', input, display, playerAction);

    defer map.deinit();

    try map.setMonster(&player, 10, 10);
    try display.erase();

    try map.drawRoom(5, 5, 15, 15);

    // TODO: Some kind of display abstraction or put in the display provider
    // and routed through the player

    var action = ThingAction.init(ActionType.NoAction);
    while (action.type != ActionType.QuitAction) {
        for (0..24) |y| {
            for (0..80) |x| {
                const c = try map.getChar(@intCast(x), @intCast(y));
                try display.mvaddch(@intCast(x), @intCast(y), c);
            }
        }

        try display.refresh();
        action = try player.doAction();
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
    }
}

fn playerAction(self: *Thing) !ThingAction {
    var ret = ThingAction.init(ActionType.NoAction);
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
