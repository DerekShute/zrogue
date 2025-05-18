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
x: u16,
y: u16,
// TODO: cursor management

//
// Constructor
//

pub fn init(minx: u8, miny: u8, allocator: std.mem.Allocator) Provider.Error!Self {
    if (global_win != null) {
        return Provider.Error.AlreadyInitialized;
    }

    const res = curses.initscr();
    errdefer {
        _ = curses.endwin();
    }
    if (res) |res_val| {
        global_win = res_val;
    }

    // Instantly process events, and activate arrow keys
    // TODO Future: mouse events
    _ = curses.raw();
    _ = curses.noecho();
    _ = curses.keypad(global_win, true);

    if (try checkError(curses.getmaxx(global_win)) < minx) {
        return Provider.Error.DisplayTooSmall;
    }
    if (try checkError(curses.getmaxy(global_win)) < miny) {
        return Provider.Error.DisplayTooSmall;
    }

    _ = try checkError(curses.noecho());
    _ = try checkError(curses.curs_set(0));

    return .{
        .allocator = allocator,
        .x = 0,
        .y = 0,
    };
}

pub fn provider(self: *Self) Provider {
    return .{
        .ptr = self,
        .vtable = &.{
            .endwin = endwin,
            .erase = erase,
            .getmaxx = getmaxx,
            .getmaxy = getmaxy,
            .mvaddch = mvaddch,
            .mvaddstr = mvaddstr,
            .refresh = refresh,
            .setTile = setTile,
            .getCommand = getCommand,
        },
    };
}

//
// Destructor
//

fn endwin(ptr: *anyopaque) void {
    _ = ptr;
    global_win = null;
    _ = curses.endwin(); // Liberal shut-up-and-do-it
}

//
// Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn erase(ptr: *anyopaque) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    _ = try checkError(curses.werase(global_win));
}

pub fn getmaxy(ptr: *anyopaque) Provider.Error!u16 {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    return @intCast(try checkError(curses.getmaxy(global_win)));
}

pub fn getmaxx(ptr: *anyopaque) Provider.Error!u16 {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    return @intCast(try checkError(curses.getmaxx(global_win)));
}

fn setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    _ = try checkError(curses.mvaddch(y, x, mapToChar(t)));
    return;
}

fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    _ = try checkError(curses.mvaddch(y, x, ch));
    return;
}

fn mvaddstr(ptr: *anyopaque, x: u16, y: u16, s: []const u8) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    if (s.len > 0) { // Interface apparently insists
        _ = try checkError(curses.mvaddnstr(y, x, s.ptr, @intCast(s.len)));
    }
}

fn refresh(ptr: *anyopaque) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    _ = try checkError(curses.refresh());
    return;
}

fn getCommand(ptr: *anyopaque) Provider.Error!Command {
    _ = ptr;
    // TODO Future: resize 'key'
    return switch (try checkError(curses.getch())) {
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
// Unit Tests
//
const expectError = std.testing.expectError;

// Kind of nonsense because we phony up the non-init situation
test "Display method use without initialization (after endwin)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var p = Self{ .allocator = allocator, .x = 0, .y = 0 };
    var d = p.provider();

    try expectError(Provider.Error.NotInitialized, d.erase());
    try expectError(Provider.Error.NotInitialized, d.getmaxx());
    try expectError(Provider.Error.NotInitialized, d.getmaxy());
    try expectError(Provider.Error.NotInitialized, d.mvaddch(1, 1, '+'));
    try expectError(Provider.Error.NotInitialized, d.refresh());
}

// EOF
