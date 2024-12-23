const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const curses = @cImport(@cInclude("curses.h"));

//
// Lifted from https://github.com/Akuli/curses-minesweeper
//

fn checkError(res: c_int) !c_int {
    if (res == curses.ERR) {
        return error.CursesError;
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
        // Slightly more liberal just in case something to scrape up
        global_win = null;
        _ = checkError(curses.endwin()) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            return; // No complaints just do it
        };
    }

    //
    // Methods
    //

    fn erase(ptr: *anyopaque) void {
        _ = ptr;
        _ = checkError(curses.werase(global_win)) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            return; // TODO: Is there a better paradigm?
        };
    }

    pub fn getmaxy(ptr: *anyopaque) u16 {
        _ = ptr;
        return @intCast(curses.getmaxy(global_win));
    }
    pub fn getmaxx(ptr: *anyopaque) u16 {
        _ = ptr;
        return @intCast(curses.getmaxx(global_win));
    }

    fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) void {
        _ = ptr;
        _ = checkError(curses.mvwaddch(global_win, y, x, ch)) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            return; // TODO awful
        };
    }

    fn refresh(ptr: *anyopaque) void {
        _ = ptr;
        _ = checkError(curses.refresh()) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            return; // TODO awful
        };
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

    fn getch(ptr: *anyopaque) u8 {
        _ = ptr;
        _ = checkError(curses.wgetch(global_win)) catch |err| {
            std.debug.print("Error: {}\n", .{err});
            // TODO not right at all
        };
        return 0; // TODO figure out c_int conversion
    }
};

pub const CursesInitReturn = struct {
    display: CursesDisplayProvider,
    input: CursesInputProvider,
};

pub fn init(allocator: std.mem.Allocator) !CursesInitReturn {
    if (global_win != null) {
        return error.CursesAlreadyInUse;
    }

    const res = curses.initscr();
    if (res) |res_val| {
        global_win = res_val;
    }

    return .{
        .display = .{
            .allocator = allocator,
            .x = 0,
            .y = 0,
        },
        .input = .{},
    };
}

// EOF
