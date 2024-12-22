const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;

const level = @import("level.zig");

pub fn run(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !void {
    const map = try level.Map.init(allocator, 24, 80);
    defer map.deinit();

    display.initscr();
    defer display.endwin();
    display.erase();

    try map.drawRoom(.{ 5, 5 }, .{ 15, 15 });

    for (0..24) |y| {
        for (0..80) |x| {
            const c = try map.charAt(.{ @truncate(x), @truncate(y) });
            try display.mvaddch(@intCast(y), @intCast(x), c);
        }
    }

    display.refresh();
    _ = input.getch();
}

// EOF
