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
    deinit: *const fn (ctx: *anyopaque) void,
    // display
    mvaddstr: *const fn (ctx: *anyopaque, x: u16, y: u16, s: []const u8) Error!void,
    refresh: *const fn (ctx: *anyopaque) Error!void,
    setTile: *const fn (ctx: *anyopaque, x: u16, y: u16, t: MapTile) Error!void,
    // input
    getCommand: *const fn (ctx: *anyopaque) Command,
};

//
// Structure Members
//
//  Hiding 'initialized' here would require back pointers from interface ctx
//  to the Provider containment

ptr: *anyopaque,
vtable: *const VTable,

//
// Constructor and destructor
//

pub inline fn deinit(self: Self) void {
    self.vtable.deinit(self.ptr);
}

//
// Methods
//

pub inline fn mvaddstr(self: Self, x: u16, y: u16, s: []const u8) Error!void {
    try self.vtable.mvaddstr(self.ptr, x, y, s);
}

pub inline fn refresh(self: Self) Error!void {
    return self.vtable.refresh(self.ptr);
}

pub inline fn setTile(self: Self, x: u16, y: u16, t: MapTile) Error!void {
    try self.vtable.setTile(self.ptr, x, y, t);
}

pub inline fn getCommand(self: Self) Command {
    return self.vtable.getCommand(self.ptr);
}

//
// MockProvider for testing purposes
//

pub const MockProvider = struct {
    initialized: bool,
    maxx: i16, // Match ncurses for now
    maxy: i16,
    x: i16 = 0,
    y: i16 = 0,
    command_list: []Command = undefined,
    command_index: u16 = 0,

    pub const MockConfig = struct {
        maxx: i16,
        maxy: i16,
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
                .deinit = mock_deinit,
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

    fn mock_deinit(ptr: *anyopaque) void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        self.initialized = false;
        return;
    }

    fn mock_mvaddstr(ptr: *anyopaque, x: u16, y: u16, s: []const u8) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        _ = x;
        _ = y;
        _ = s;
        return;
    }

    fn mock_refresh(ptr: *anyopaque) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        return;
    }

    fn mock_setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) Error!void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return Error.NotInitialized;
        }
        _ = x;
        _ = y;
        _ = t;
        return;
    }

    fn mock_getCommand(ptr: *anyopaque) Command {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            @panic("mock_getCommand before initialized");
        }
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

const expectError = std.testing.expectError;

var testlist = [_]Command{
    .goWest,
    .quit,
};

test "Basic use of mock provider" {
    var p = MockProvider.init(.{ .maxx = 40, .maxy = 60, .commands = &testlist });
    var d = p.provider();
    defer d.deinit();

    try d.refresh();
    try d.mvaddstr(0, 0, "frotz");
}

test "Method use after deinit" {
    var p = MockProvider.init(.{ .maxx = 50, .maxy = 50, .commands = &testlist });
    var d = p.provider();

    d.deinit();
    // getCommand will panic
    try expectError(Error.NotInitialized, d.refresh());
    try expectError(Error.NotInitialized, d.setTile(0, 0, .floor));
    try expectError(Error.NotInitialized, d.mvaddstr(0, 0, "frotz"));
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var display_fields = genFields(Self);

// EOF
