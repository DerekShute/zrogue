const std = @import("std");
const stdout = std.io.getStdOut().writer();

const curses = @import("curses.zig");
const DisplayProvider = @import("display.zig").DisplayProvider;
const game = @import("game.zig");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;

const Player = @import("player.zig").Player;
const LevelConfig = @import("new_level.zig").LevelConfig;

//
// Panic handler
//
// This is reached from the @panic builtin, and we're trying to unwind
// the curses windowing.  The stack trace dump is based on review of the
// std.debug sources.
//
// For the moment at least this uses @trap(), and on Ubuntu Linux with
// the right settings will generate a core file, which is the gold standard
// for figuring out what went awry.
//

var p_display: DisplayProvider = undefined;

pub const panic = std.debug.FullPanic(zroguePanic);

fn zroguePanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    p_display.endwin();
    std.debug.print("The dungeon collapses! {s}\n", .{msg});
    std.debug.dumpCurrentStackTrace(first_trace_addr);
    @trap();
}

//
// Main entrypoint
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();

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
    p_display = display;
    const input = providers.i.provider();
    defer display.endwin();

    const player = try Player.init(allocator, input, display);
    defer player.deinit();

    // TODO: command line option to force the test map
    const config = LevelConfig{
        .allocator = allocator,
        .rand = &r,
        .player = player.toThing(),
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
        .mapgen = .ROGUE,
    };

    try game.run(config);
}

//
// Unit tests
//

test "run the game" {
    const allocator = std.testing.allocator;
    const Command = zrogue.Command;
    const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
    const MockInputProvider = @import("input.zig").MockInputProvider;

    // Maximum sizes allowed is the minimum size of the curses display
    var md = MockDisplayProvider.init(.{ .maxx = zrogue.DISPLAY_MINX, .maxy = zrogue.DISPLAY_MINY });
    const display = md.provider();
    defer display.endwin();

    // TODO: need a recording to iterate through
    var commandlist = [_]Command{
        Command.goWest,
        Command.goEast,
        Command.goNorth,
        Command.goSouth,
        Command.ascend,
        Command.descend,
        Command.takeItem,
        Command.wait,
        Command.quit,
    };
    var mi = MockInputProvider.init(.{ .commands = &commandlist });
    const input = mi.provider();

    const player = try Player.init(allocator, input, display);
    defer player.deinit();

    const config = LevelConfig{
        .allocator = allocator,
        .player = player.toThing(),
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
        .mapgen = .TEST,
    };

    try game.run(config);

    // TODO: must be a way to test for all leaks (of display still init, etc.)
}

// EOF
