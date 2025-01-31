const std = @import("std");
const stdout = std.io.getStdOut().writer();

const curses = @import("curses.zig");
const game = @import("game.zig");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;

const Player = @import("player.zig").Player;

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

    const player = try Player.init(allocator, input, display);
    defer player.deinit();
    try game.run(allocator, player.toThing());
}

//
// Unit tests
//

test "run the game" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // TODO: use testing allocator

    const Command = zrogue.Command;
    const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
    const MockInputProvider = @import("input.zig").MockInputProvider;

    // Maximum sizes allowed is the minimum size of the curses display
    var md = MockDisplayProvider.init(.{ .maxx = zrogue.DISPLAY_MINX, .maxy = zrogue.DISPLAY_MINY });
    const display = md.provider();
    defer display.endwin();

    // This is instrumented to quit
    var mi = MockInputProvider.init(.{ .command = Command.quit });
    const input = mi.provider();

    const player = try Player.init(allocator, input, display);
    defer player.deinit();
    try game.run(allocator, player.toThing());

    // TODO: must be a way to test for all leaks (of display still init, etc.)
}

// EOF
