//!
//! ncurses frontend, creating a Provider from it
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const Command = zrogue.Command;
const MapTile = zrogue.MapTile;
const ZrogueError = zrogue.ZrogueError;
const Provider = @import("Provider.zig");
const curses = @cImport(@cInclude("curses.h"));

const Self = @This();

//
// Lifted from https://github.com/Akuli/curses-minesweeper
//
// Causes:
//
//   * Move cursor to x,y not supported by window size
//
fn checkError(res: c_int) Provider.Error!c_int {
    if (res == curses.ERR) {
        return Provider.Error.ProviderError; // Cop-out
    }
    return res;
}

//
// Convert map location to what it is displayed as
//
fn mapToChar(ch: MapTile) u8 {
    const c: u8 = switch (ch) {
        .unknown => ' ',
        .floor => '.',
        .gold => '$',
        .wall => '#',
        .secret_door => '#', // Unfound: looks like wall
        .door => '+',
        .player => '@',
        .stairs_down => '>',
        .stairs_up => '<',
    };
    return c;
}

//
// Global state
//

var global_win: ?*curses.WINDOW = null;

//
// Members
//

allocator: std.mem.Allocator,
display_map: Provider.DisplayMap = undefined,
// Message log which should be done better
// REFACTOR: part of Provider, imported from player
msgmem: [zrogue.MESSAGE_MAXSIZE]u8 = undefined,
msgbuf: []u8 = &.{},
stats: Provider.VisibleStats = undefined,
x: u16 = 0,
y: u16 = 0,

// TODO: cursor management

//
// Constructor
//

pub fn init(minx: u8, miny: u8, allocator: std.mem.Allocator) Provider.Error!Self {
    if (global_win != null) {
        return Provider.Error.AlreadyInitialized;
    }

    // Note technically can fail
    const res = curses.initscr();
    errdefer {
        _ = curses.endwin(); // error only if window uninitialized.
    }
    if (res) |res_val| {
        global_win = res_val;
    }

    const display_map = try Provider.DisplayMap.config(allocator, @intCast(minx), @intCast(miny));
    errdefer display_map.deinit();

    // Instantly process events, and activate arrow keys
    // TODO Future: mouse events

    // raw/keypad/noecho: no defined error cases
    _ = checkError(curses.raw()) catch unreachable;
    _ = checkError(curses.keypad(global_win, true)) catch unreachable;
    _ = checkError(curses.noecho()) catch unreachable;
    // curs_set: ERR only if argument value is unsupported
    _ = checkError(curses.curs_set(0)) catch unreachable;

    // getmaxx/getmaxy ERR iff null window parameter
    const display_maxx = checkError(curses.getmaxx(global_win)) catch unreachable;
    const display_maxy = checkError(curses.getmaxy(global_win)) catch unreachable;
    // TODO: off by one error here
    if ((display_maxx < minx) or (display_maxy < miny + 1)) {
        return Provider.Error.DisplayTooSmall;
    }

    return .{
        .allocator = allocator,
        .display_map = display_map,
        .x = minx,
        .y = miny,
    };
}

pub fn provider(self: *Self) Provider {
    return .{
        .ptr = self,
        .display_map = &self.display_map,
        .vtable = &.{
            .deinit = deinit,
            .addMessage = addMessage,
            .updateStats = updateStats,
            .getCommand = getCommand,
        },
    };
}

//
// Destructor
//

fn deinit(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.display_map.deinit();
    global_win = null;
    _ = curses.endwin(); // Liberal shut-up-and-do-it
}

//
// Gross Utility Wrappers
//

fn mvaddstr(x: u16, y: u16, s: []const u8) void {
    // TODO errors here probably only because of display sizing

    if (s.len > 0) { // Interface apparently insists
        _ = checkError(curses.mvaddnstr(y, x, s.ptr, @intCast(s.len))) catch unreachable;
    }
}

fn refresh() void {
    // refresh: no error cases defined
    _ = checkError(curses.refresh()) catch unreachable;
}

//
// Input Utility
//

fn readCommand() Command {
    // TODO Future: resize 'key'

    const ch = checkError(curses.getch()) catch unreachable;
    return switch (ch) {
        curses.KEY_LEFT => .goWest,
        curses.KEY_RIGHT => .goEast,
        curses.KEY_UP => .goNorth,
        curses.KEY_DOWN => .goSouth,
        '<' => .ascend,
        '>' => .descend,
        '?' => .help,
        'q' => .quit,
        's' => .search,
        ',' => .takeItem,
        else => .wait,
    };
}

//
// Display Utility
//

fn displayHelp() void {
    // FIXME : This is horrible and adding to it is painful
    mvaddstr(0, 0, "                                                 ");
    mvaddstr(0, 1, "         Welcome to the Dungeon of Doom          ");
    mvaddstr(0, 2, "                                                 ");
    mvaddstr(0, 3, " Use the arrow keys to move through the dungeon  ");
    mvaddstr(0, 4, " and collect gold.  You can only return to the   ");
    mvaddstr(0, 5, " surface after you have descended to the bottom. ");
    mvaddstr(0, 6, "                                                 ");
    mvaddstr(0, 7, " Commands include:                               ");
    mvaddstr(0, 8, "    ? - help (this)                              ");
    mvaddstr(0, 9, "    > - descend stairs (\">\")                   ");
    mvaddstr(0, 10, "    < - ascend stairs (\"<\")                   ");
    mvaddstr(0, 11, "    , - pick up gold  (\"$\")                   ");
    mvaddstr(0, 12, "    s - search for hidden doors                 ");
    mvaddstr(0, 13, "    q - chicken out and quit                    ");
    mvaddstr(0, 14, "                                                ");
    mvaddstr(0, 15, " [type a command or any other key to continue]  ");
    mvaddstr(0, 16, "                                                ");
    refresh();
}

fn displayScreen(self: *Self) !void {
    // TODO: only updates

    //
    // Top line: messages
    //
    // TODO: too narrow
    //
    mvaddstr(0, 0, "                                                  ");
    mvaddstr(0, 0, self.msgbuf);
    self.msgbuf = &.{}; // Zap it

    //
    // Bottom line: stat block
    //
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    //
    // TODO: defined length, here
    var buf: [80]u8 = undefined; // does this need to be allocated?  size?

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const output = .{
        self.stats.depth,
        self.stats.purse,
    };

    // We know that error.NoSpaceLeft can't happen here
    const line = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    // TODO if too narrow
    // TODO explicitly the bottom row, whatever the current screen height
    mvaddstr(0, @intCast(self.y), line);

    //
    // Output map display
    //
    // TODO off by one
    // TODO iterator
    //
    const map = self.display_map;
    for (0..@intCast(self.y - 1)) |y| {
        for (0..@intCast(self.x)) |x| {
            const t = map.find(@intCast(x), @intCast(y)) catch unreachable; // TODO
            _ = checkError(curses.mvaddch(@intCast(y + 1), @intCast(x), mapToChar(t.tile))) catch unreachable;
        }
    }

    refresh();
}

//
// VTable Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn addMessage(ptr: *anyopaque, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.msgbuf = &self.msgmem; // Reset slice to max length and content
    @memcpy(self.msgbuf[0..msg.len], msg);
    self.msgbuf = self.msgbuf[0..msg.len]; // Fix up the slice for length
}

fn updateStats(ptr: *anyopaque, stats: Provider.VisibleStats) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.stats = stats;
}

fn getCommand(ptr: *anyopaque) Command {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (global_win == null) {
        // Punish programmatic errors
        @panic("getCommand but not initialized");
    }

    self.displayScreen() catch unreachable; // TODO

    var cmd = readCommand();
    while (cmd == .help) {
        displayHelp();
        cmd = readCommand();
    }
    return cmd;
}

//
// Unit Tests
//
const expectError = std.testing.expectError;

// TODO alloc fail test

// EOF
