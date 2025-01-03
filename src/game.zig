const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const ActionEvent = @import("zrogue.zig").ActionEvent;

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
    for (0..24) |y| {
        for (0..80) |x| {
            const c = try map.getChar(@intCast(x), @intCast(y));
            try display.mvaddch(@intCast(x), @intCast(y), c);
        }
    }

    try display.refresh();

    var event = ActionEvent.NoEvent;
    while (event == ActionEvent.NoEvent) {
        event = try player.doAction();
    }
}

fn playerAction(self: *Thing) !ActionEvent {
    const ch = try self.input.getch();

    try self.display.mvaddch(0, 0, @intCast(ch));

    if (ch == 'q') {
        return ActionEvent.QuittingGame;
    }
    return ActionEvent.NoEvent;
}
// EOF
