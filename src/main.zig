const std = @import("std");
const stdout = std.io.getStdOut().writer();

const curses = @import("curses.zig");
const game = @import("game.zig");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var providers = curses.init(zrogue.DISPLAY_MINX, zrogue.DISPLAY_MINY, allocator) catch |err| switch (err) {
        ZrogueError.DisplayTooSmall => {
            try stdout.print("ERROR: Minimum {}x{} display required\n", .{ zrogue.DISPLAY_MINX, zrogue.DISPLAY_MINY });
            std.process.exit(0);
        },
        else => {
            try stdout.print("Unexpected error {}\n\n", .{err});
            std.process.exit(1);
        },
    };
    const display = providers.d.provider();
    const input = providers.i.provider();
    defer display.endwin();

    try game.run(allocator, input, display);
}

//
// Unit tests
//

test "run the game" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // TODO: use testing allocator

    const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
    const MockInputProvider = @import("input.zig").MockInputProvider;

    // Maximum sizes allowed is the minimum size of the curses display
    var md = MockDisplayProvider.init(.{ .maxx = zrogue.DISPLAY_MINX, .maxy = zrogue.DISPLAY_MINY });
    const display = md.provider();
    defer display.endwin();

    // This is instrumented to quit
    var mi = MockInputProvider.init(.{ .keypress = 'q' });
    const input = mi.provider();

    try game.run(allocator, input, display);

    // TODO: must be a way to test for all leaks (of display still init, etc.)
}

// EOF
