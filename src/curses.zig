const std = @import("std");
const display = @import("display.zig");
const ZrogueError = @import("zrogue.zig").ZrogueError;
const DisplayProvider = display.DisplayProvider;
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
// Global state
//

var global_win: ?*curses.WINDOW = null;

//
// Providing a Curses-based Display
//
//
// * (0,0) is top left corner, Y incrementing down the display, X incrementing right
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

    fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) ZrogueError!void {
        _ = ptr;
        if (global_win == null) {
            return ZrogueError.NotInitialized;
        }
        _ = try checkError(curses.mvaddch(y, x, ch)); // TODO not using windowed interface here
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

pub const CursesInputProvider = struct {
    //
    // Constructor
    //

    pub fn provider(self: *CursesInputProvider) InputProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .getch = getch,
            },
        };
    }

    //
    // Methods
    //

    fn getch(ptr: *anyopaque) ZrogueError!usize {
        _ = ptr;
        return @intCast(try checkError(curses.wgetch(global_win)));
    }
};

pub const CursesInitReturn = struct {
    d: CursesDisplayProvider,
    i: CursesInputProvider,
};

pub fn init(allocator: std.mem.Allocator) !CursesInitReturn {
    if (global_win != null) {
        return error.CursesAlreadyInUse;
    }

    const res = curses.initscr();
    if (res) |res_val| {
        global_win = res_val;
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
