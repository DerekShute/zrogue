const std = @import("std");
const zrogue = @import("zrogue.zig");
const Command = zrogue.Command;
const MapTile = zrogue.MapTile;
const ZrogueError = zrogue.ZrogueError;
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const curses = @cImport(@cInclude("curses.h"));

//
// Lifted from https://github.com/Akuli/curses-minesweeper
//
// Causes:
//
//   * Move cursor to x,y not supported by window size
//
fn checkError(res: c_int) ZrogueError!c_int {
    if (res == curses.ERR) {
        return ZrogueError.ImplementationError;
    }
    return res;
}

//
// Convert map location to what it is displayed as
//
fn mapToChar(ch: MapTile) u8 {
    const c: u8 = switch (ch) {
        MapTile.unknown => ' ',
        MapTile.floor => '.',
        MapTile.wall => '#',
        MapTile.player => '@',
    };
    return c;
}

//
// Global state
//

var global_win: ?*curses.WINDOW = null;

//
// Providing a Curses-based Display
//
//
// * (0,0) is top left corner, Y incrementing down the display, X incrementing right
//

// ===================
//
// DisplayProvider implementation for Curses
//
// DOT CursesDisplayProvider -> DisplayProvider [label="implements"]
// DOT CursesDisplayProvider -> DisplayVTable [label="interface"]
//
pub const CursesDisplayProvider = struct {
    allocator: std.mem.Allocator,
    x: u16,
    y: u16,
    // todo: cursor

    pub fn provider(self: *CursesDisplayProvider) DisplayProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .endwin = endwin,
                .erase = erase,
                .getmaxx = getmaxx,
                .getmaxy = getmaxy,
                .mvaddch = mvaddch,
                .refresh = refresh,
                .setTile = setTile,
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

    fn erase(ptr: *anyopaque) ZrogueError!void {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        _ = try checkError(curses.werase(global_win));
    }

    pub fn getmaxy(ptr: *anyopaque) ZrogueError!u16 {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        return @intCast(try checkError(curses.getmaxy(global_win)));
    }

    pub fn getmaxx(ptr: *anyopaque) ZrogueError!u16 {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        return @intCast(try checkError(curses.getmaxx(global_win)));
    }

    fn setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) ZrogueError!void {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        _ = try checkError(curses.mvaddch(y, x, mapToChar(t)));
        return;
    }

    fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) ZrogueError!void {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        _ = try checkError(curses.mvaddch(y, x, ch));
        return;
    }

    fn refresh(ptr: *anyopaque) ZrogueError!void {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        _ = try checkError(curses.refresh());
        return;
    }
};

// ===================
//
// InputProvider implementation for Curses
//
// DOT CursesInputProvider -> InputProvider [label="implements"]
// DOT CursesInputProvider -> InputVTable [label="interface"]
//
pub const CursesInputProvider = struct {
    //
    // Constructor
    //

    pub fn provider(self: *CursesInputProvider) InputProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .getCommand = getCommand,
            },
        };
    }

    //
    // Methods
    //

    // abstract ncurses code to internal 'command'.  Note that this is unhelpful for selection of items using a-z etc.
    //
    // TODO: resize 'key'
    fn getCommand(ptr: *anyopaque) ZrogueError!Command {
        _ = ptr;
        const cmd = switch (try checkError(curses.getch())) {
            curses.KEY_LEFT => Command.goWest,
            curses.KEY_RIGHT => Command.goEast,
            curses.KEY_UP => Command.goNorth,
            curses.KEY_DOWN => Command.goSouth,
            '>' => Command.descend,
            '<' => Command.ascend,
            'q' => Command.quit,
            else => Command.wait,
        };
        return cmd;
    }
};

// ===================
//
// Return from the config routine, handing off the two providers
//
// DOT CursesInitReturn -> CursesDisplayProvider [label="contains"]
// DOT CursesInitReturn -> CursesInputProvider [label="contains"]
//
pub const CursesInitReturn = struct {
    d: CursesDisplayProvider,
    i: CursesInputProvider,
};

pub fn init(minx: u8, miny: u8, allocator: std.mem.Allocator) ZrogueError!CursesInitReturn {
    if (global_win != null) {
        return ZrogueError.AlreadyInUse;
    }

    const res = curses.initscr();
    errdefer {
        _ = curses.endwin();
    }
    if (res) |res_val| {
        global_win = res_val;
    }

    // Instantly process events, and activate arrow keys
    // TODO: mouse events
    _ = curses.raw();
    _ = curses.noecho();
    _ = curses.keypad(global_win, true);

    if (try checkError(curses.getmaxx(global_win)) < minx) {
        return ZrogueError.DisplayTooSmall;
    }
    if (try checkError(curses.getmaxy(global_win)) < miny) {
        return ZrogueError.DisplayTooSmall;
    }

    _ = try checkError(curses.noecho());
    _ = try checkError(curses.curs_set(0));

    return .{
        .d = .{
            .allocator = allocator,
            .x = 0,
            .y = 0,
        },
        .i = .{},
    };
}

//
// Unit Tests
//

// Kind of nonsense because we phony up the non-init situation
test "Display method use without initialization (after endwin)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var p = CursesDisplayProvider{ .allocator = allocator, .x = 0, .y = 0 };
    var d = p.provider();

    try std.testing.expectError(ZrogueError.NotInitialized, d.erase());
    try std.testing.expectError(ZrogueError.NotInitialized, d.getmaxx());
    try std.testing.expectError(ZrogueError.NotInitialized, d.getmaxy());
    try std.testing.expectError(ZrogueError.NotInitialized, d.mvaddch(1, 1, '+'));
    try std.testing.expectError(ZrogueError.NotInitialized, d.refresh());
}

// EOF
