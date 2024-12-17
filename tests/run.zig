const std = @import("std");
const MockDisplayProvider = @import("../src/display.zig").MockDisplayProvider;
const level = @import("../src/level.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var p = MockDisplayProvider.init(.{ .maxx = 80, .maxy = 24 });
var d = p.provider();

test "Create a display and write to it" {
    const map = try level.Map.init(allocator, 24, 80);
    defer map.deinit();

    d.initscr();
    defer d.endwin();
    d.erase();

    try map.drawRoom(.{ 5, 5 }, .{ 15, 15 });

    for (0..24) |y| {
        for (0..80) |x| {
            const c = try map.charAt(.{ @truncate(x), @truncate(y) });
            try d.mvaddch(@intCast(y), @intCast(x), c);
        }
    }

    d.refresh();
}

// EOF
