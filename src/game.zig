const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;

const level = @import("level.zig");
const Thing = @import("thing.zig").Thing;

// TODO: test maxx, maxy
pub fn run(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !void {
    const map = try level.Map.init(allocator, 24, 80);
    var player = Thing{ .xy = .{ 10, 10 }, .ch = '@' };

    defer map.deinit();

    try map.setMonster(&player, .{ 10, 10 });
    try display.erase();

    try map.drawRoom(.{ 5, 5 }, .{ 15, 15 });

    // TODO: Some kind of display abstraction or put in the display provider
    for (0..24) |y| {
        for (0..80) |x| {
            const c = try map.getChar(.{ @truncate(x), @truncate(y) });
            try display.mvaddch(@intCast(x), @intCast(y), c);
        }
    }

    try display.refresh();
    _ = input.getch();
}

// EOF
