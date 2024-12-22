const std = @import("std");
const curses = @cImport(@cInclude("curses.h"));
const level = @import("level.zig");

// TODO terminal size, map size constants

pub fn main() !void {
    const allocator = std.heap.c_allocator; // TODO better options?
    const map = try level.Map.init(allocator, 24, 80);
    defer map.deinit();
    try map.drawRoom(.{ 5, 5 }, .{ 15, 15 });

    _ = curses.initscr();

    for (0..24) |y| {
        for (0..80) |x| {
            const c = try map.charAt(.{ @truncate(x), @truncate(y) });
            _ = curses.mvaddch(@intCast(y), @intCast(x), c);
        }
    }
    _ = curses.refresh();
    _ = curses.getch();
    _ = curses.endwin();
}

test "run the game" {
    const game = @import("game.zig");
    const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
    const MockInputProvider = @import("input.zig").MockInputProvider;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var md = MockDisplayProvider.init(.{ .maxx = 80, .maxy = 24 });
    const display = md.provider();

    var mi = MockInputProvider.init(.{ .keypress = '*' });
    const input = mi.provider();

    try game.run(allocator, input, display);
}

// EOF
