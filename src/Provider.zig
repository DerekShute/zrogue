//!
//! input/output Provider, plus Mock for testing
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const MapTile = zrogue.MapTile;
const Command = zrogue.Command;

const Self = @This();

//
// Errors that can come out of this or of any implementation
//
pub const Error = error{
    NotInitialized,
    AlreadyInitialized,
    ProviderError,
    DisplayTooSmall, // Curses
};

//
// VTable for implementation to manage
//
pub const VTable = struct {
    // constructor/destructor
    endwin: *const fn (ctx: *anyopaque) void,
    // display
    erase: *const fn (ctx: *anyopaque) Error!void,
    getmaxx: *const fn (ctx: *anyopaque) Error!u16,
    getmaxy: *const fn (ctx: *anyopaque) Error!u16,
    mvaddch: *const fn (ctx: *anyopaque, x: u16, y: u16, ch: u8) Error!void,
    mvaddstr: *const fn (ctx: *anyopaque, x: u16, y: u16, s: []const u8) Error!void,
    refresh: *const fn (ctx: *anyopaque) Error!void,
    setTile: *const fn (ctx: *anyopaque, x: u16, y: u16, t: MapTile) Error!void,
    // input
    getCommand: *const fn (ctx: *anyopaque) Error!Command,
};

//
// Structure Members
//
ptr: *anyopaque,
vtable: *const VTable,

//
// Constructor and destructor
//

pub inline fn endwin(self: Self) void {
    self.vtable.endwin(self.ptr);
}

//
// Methods
//

pub inline fn erase(self: Self) Error!void {
    return self.vtable.erase(self.ptr);
}

pub inline fn getmaxx(self: Self) Error!u16 {
    return self.vtable.getmaxx(self.ptr);
}

pub inline fn getmaxy(self: Self) Error!u16 {
    return self.vtable.getmaxy(self.ptr);
}

pub inline fn mvaddch(self: Self, x: u16, y: u16, ch: u8) Error!void {
    try self.vtable.mvaddch(self.ptr, x, y, ch);
}

pub inline fn mvaddstr(self: Self, x: u16, y: u16, s: []const u8) Error!void {
    try self.vtable.mvaddstr(self.ptr, x, y, s);
}

pub inline fn refresh(self: Self) Error!void {
    return self.vtable.refresh(self.ptr);
}

pub inline fn setTile(self: Self, x: u16, y: u16, t: MapTile) Error!void {
    try self.vtable.setTile(self.ptr, x, y, t);
}

pub inline fn getCommand(self: Self) Error!Command {
    return self.vtable.getCommand(self.ptr);
}

//
// MockProvider for testing purposes
//

pub const MockProvider = struct {
    initialized: bool,
    maxx: u16,
    maxy: u16,
    x: u16 = 0,
    y: u16 = 0,
    command_list: []Command = undefined,
    command_index: u16 = 0,

    pub const MockConfig = struct {
        maxx: u16,
        maxy: u16,
        commands: []Command,
    };

    //
    // Constructor
    //

    pub fn init(config: MockConfig) MockProvider {
        return MockProvider{
            .initialized = true,
            .maxx = config.maxx,
            .maxy = config.maxy,
            .command_list = config.commands,
        };
    }

    pub fn provider(self: *MockProvider) Self {
        return .{
            .ptr = self,
            .vtable = &.{
                .endwin = mock_endwin,
                .erase = mock_erase,
                .getmaxx = mock_getmaxx,
                .getmaxy = mock_getmaxy,
                .mvaddch = mock_mvaddch,
                .mvaddstr = mock_mvaddstr,
                .refresh = mock_refresh,
                .setTile = mock_setTile,
                .getCommand = mock_getCommand,
            },
        };
    }

    //
    // Methods
    //

    fn mock_endwin(ptr: *anyopaque) void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        self.initialized = false;
        return;
    }

    fn mock_erase(ptr: *anyopaque) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        return;
    }

    fn mock_getmaxx(ptr: *anyopaque) Error!u16 {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        return self.maxx;
    }

    fn mock_getmaxy(ptr: *anyopaque) Error!u16 {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        return self.maxy;
    }

    fn mock_mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = ch;
        return;
    }

    fn mock_mvaddstr(ptr: *anyopaque, x: u16, y: u16, s: []const u8) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = s;
        return;
    }

    fn mock_refresh(ptr: *anyopaque) Error!void {
        _ = ptr;
        return;
    }

    fn mock_setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = t;
        return;
    }

    fn mock_getCommand(ptr: *anyopaque) !Command {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        const i = self.command_index;
        if (i >= self.command_list.len) {
            @panic("No more mock commands to provide");
        }
        self.command_index += 1;
        return self.command_list[i];
    }
}; // MockProvider

//
// Unit tests
//

var testlist = [_]Command{
    .goWest,
    .quit,
};

test "Basic use of mock provider" {
    var p = MockProvider.init(.{ .maxx = 40, .maxy = 60, .commands = &testlist });
    var d = p.provider();
    defer d.endwin();

    try d.erase();
    try d.refresh();

    try std.testing.expect(try d.getmaxx() == 40);
    try std.testing.expect(try d.getmaxy() == 60);
}

test "Method use after endwin" {
    var p = MockProvider.init(.{ .maxx = 50, .maxy = 50, .commands = &testlist });
    var d = p.provider();

    d.endwin();
    try std.testing.expectError(Error.NotInitialized, d.erase());
    try std.testing.expectError(Error.NotInitialized, d.getmaxx());
    try std.testing.expectError(Error.NotInitialized, d.getmaxy());
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var display_fields = genFields(Self);

// EOF
