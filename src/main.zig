//!
//! Start here
//!

const std = @import("std");

const CursesProvider = @import("curses.zig");
const Provider = @import("Provider.zig");
const game = @import("game.zig");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;

const Player = @import("player.zig").Player;
const LevelConfig = @import("new_level.zig").LevelConfig;
const ScoreList = @import("utils/ScoreList.zig");

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

var p_provider: *Provider = undefined;

pub const panic = std.debug.FullPanic(zroguePanic);

fn zroguePanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    p_provider.deinit();
    std.debug.print("The dungeon collapses! {s}\n", .{msg});
    std.debug.dumpCurrentStackTrace(first_trace_addr);
    @trap();
}

// Command arguments

const help_arg_flags = [_][]const u8{ "-h", "-help", "--help" };

fn arg_in_list(programarg: []u8, l: []const []const u8) bool {
    for (l) |a| {
        if (std.mem.eql(u8, programarg, a)) {
            return true;
        }
    }
    return false;
}

fn print_help(file: std.fs.File) !void {
    const help =
        \\Zrogue : Adventuring in the Dungeons of Doom
        \\
        \\ This program requires a 80x24 text display.
        \\
        \\ options:
        \\   --help, -h : help
        \\
        \\ Press '?' for in-game help
        \\
    ;
    const out = file.writer(); // Anytype grinds my gears
    try out.print("{s}\n", .{help});
}

// Map size limits

const mapsize = zrogue.Pos.init(zrogue.DISPLAY_MINX, zrogue.DISPLAY_MINY);

//
// Main entrypoint
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut();
    const stderr_out = std.io.getStdErr().writer();

    // Handle CLI arguments.  Note that this does not work from 'build run'

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len > 1) { // program name is args[0]
        for (args) |arg| {
            if (arg_in_list(arg, &help_arg_flags)) {
                try print_help(stdout);
                std.process.exit(0);
            }
            // TODO: set random seed, wizard mode, save game file, etc.
            // TODO: force test level
        }
        try print_help(stdout);
        std.process.exit(1);
    }

    // TODO Future: not the best place for this file
    var score_list = try ScoreList.load(allocator, "zrogue-scores.yml");
    defer score_list.finalize("zrogue-scores.yml") catch |err| {
        stderr_out.print("Unexpected error {}\n\n", .{err}) catch {};
    };

    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();

    var curses = CursesProvider.init(mapsize.getX(), mapsize.getY(), allocator) catch |err| switch (err) {
        Provider.Error.DisplayTooSmall => {
            try stderr_out.print("ERROR: Minimum {}x{} display required\n", .{ mapsize.getX(), mapsize.getY() });
            std.process.exit(1);
        },
        else => { // Includes out of memory
            try stderr_out.print("Unexpected error {}\n\n", .{err});
            std.process.exit(1);
        },
    };
    const provider = curses.provider();
    p_provider = provider; // Panic backdoor
    // TODO: error path is squirrelly - can't defer or errdefer because of
    // explicit handling.  Should this be nested?

    const player = try Player.init(allocator, provider, mapsize);
    defer player.deinit();

    const config = LevelConfig{
        .allocator = allocator,
        .rand = &r,
        .player = player.toThing(),
        .xSize = mapsize.getX(),
        .ySize = mapsize.getY(),
        .mapgen = .ROGUE,
    };

    try game.run(config);
    provider.deinit();

    //
    // Endgame - print the player's score.
    //
    // TODO Future: Zig std lacks 'get my user name'
    //

    const out = stdout.writer();
    const score = player.getScore();
    try out.print("Your final score: {}\n\n", .{score});
    try score_list.append("user", score);
    try out.print("High scores:\n", .{});

    var it = score_list.iterator();
    while (it.next()) |s| {
        try out.print(" * {s} : {}\n", .{ s.name, s.score });
    }
}

//
// Unit tests
//

test "run the game" {
    const allocator = std.testing.allocator;
    const Command = zrogue.Command;
    const MockProvider = @import("Provider.zig").MockProvider;

    // TODO search
    // TODO Future: need a recording to iterate through
    var commandlist = [_]Command{
        Command.help,
        Command.help, // press any key
        Command.go_west,
        Command.go_east,
        Command.go_north,
        Command.go_south,
        Command.ascend,
        Command.descend,
        Command.take_item,
        Command.wait,
        Command.quit,
    };
    var mp = try MockProvider.init(.{ .allocator = allocator, .maxx = mapsize.getX(), .maxy = mapsize.getY(), .commands = &commandlist });
    var mp_provider = mp.provider();
    defer mp_provider.deinit();

    const player = try Player.init(allocator, mp_provider, mapsize);
    defer player.deinit();

    const config = LevelConfig{
        .allocator = allocator,
        .player = player.toThing(),
        .xSize = mapsize.getX(),
        .ySize = mapsize.getY(),
        .mapgen = .TEST,
    };

    try game.run(config);

    // TODO: must be a way to test for all leaks (of display still init, etc.)
}

// EOF
