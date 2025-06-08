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
    if ((display_maxx < minx) or (display_maxy < miny)) {
        return Provider.Error.DisplayTooSmall;
    }

    return .{
        .allocator = allocator,
        .display_map = display_map,
        .x = 0,
        .y = 0,
    };
}

pub fn provider(self: *Self) Provider {
    return .{
        .ptr = self,
        .display_map = &self.display_map,
        .vtable = &.{
            .deinit = deinit,
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

fn deinit(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.display_map.deinit();
    global_win = null;
    _ = curses.endwin(); // Liberal shut-up-and-do-it
}

//
// Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) Provider.Error!void {
    _ = ptr;
    if (global_win == null) {
        return Provider.Error.NotInitialized;
    }
    _ = try checkError(curses.mvaddch(y, x, mapToChar(t)));
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
    // refresh: no error cases defined
    _ = checkError(curses.refresh()) catch unreachable;
    return;
}

fn getCommand(ptr: *anyopaque) Command {
    _ = ptr;
    if (global_win == null) {
        // Punish programmatic errors
        @panic("getCommand but not initialized");
    }

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
// Unit Tests
//
const expectError = std.testing.expectError;

// TODO alloc fail test

// EOF
