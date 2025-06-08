//!
//! input/output Provider, plus Mock for testing
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const Grid = @import("utils/grid.zig").Grid;
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
    OutOfMemory,
};

// ===================
//
// Exported player/game stats
//

pub const VisibleStats = struct {
    depth: usize = 0,
    purse: u16 = 0,
};

// ===================
//
// Map grid as informed to us by the engine
//
// Subset of map.Place
//
pub const DisplayMapTile = struct {
    tile: MapTile,
    // TODO: monster tile, item tile
};

pub const DisplayMap = Grid(DisplayMapTile);

//
// VTable for implementation to manage
//
pub const VTable = struct {
    // constructor/destructor
    deinit: *const fn (ctx: *anyopaque) void,
    // display
    addMessage: ?*const fn (ctx: *anyopaque, msg: []const u8) void,
    updateStats: ?*const fn (ctx: *anyopaque, stats: VisibleStats) void,

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
display_map: *DisplayMap = undefined,

//
// Constructor and destructor
//

pub inline fn deinit(self: Self) void {
    self.vtable.deinit(self.ptr);
}

//
// Methods
//

pub inline fn addMessage(self: Self, msg: []const u8) void {
    if (self.vtable.addMessage) |cb| {
        cb(self.ptr, msg);
    }
}

pub fn setTile(self: Self, x: u16, y: u16, t: MapTile) Error!void {
    var val = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: ignore?
    };
    val.tile = t;
}

pub fn updateStats(self: Self, stats: VisibleStats) void {
    if (self.vtable.updateStats) |cb| {
        cb(self.ptr, stats);
    }
}

pub inline fn getCommand(self: Self) Command {
    return self.vtable.getCommand(self.ptr);
}

//
// MockProvider for testing purposes
//

pub const MockProvider = struct {
    allocator: std.mem.Allocator,
    initialized: bool,
    maxx: i16, // Match ncurses for now
    maxy: i16,
    x: i16 = 0,
    y: i16 = 0,
    command_list: []Command = undefined,
    command_index: u16 = 0,
    display_map: DisplayMap = undefined,

    pub const MockConfig = struct {
        allocator: std.mem.Allocator,
        maxx: i16,
        maxy: i16,
        commands: []Command,
    };

    //
    // Constructor
    //

    pub fn init(config: MockConfig) !MockProvider {
        const display_map = try DisplayMap.config(config.allocator, @intCast(config.maxx), @intCast(config.maxy));
        errdefer display_map.deinit();
        return MockProvider{
            .allocator = config.allocator,
            .display_map = display_map,
            .initialized = true,
            .maxx = config.maxx,
            .maxy = config.maxy,
            .command_list = config.commands,
        };
    }

    pub fn provider(self: *MockProvider) Self {
        return .{
            .ptr = self,
            .display_map = &self.display_map,
            .vtable = &.{
                .deinit = mock_deinit,
                .addMessage = null,
                .updateStats = null,
                .getCommand = mock_getCommand,
            },
        };
    }

    //
    // Methods
    //

    fn mock_deinit(ptr: *anyopaque) void {
        const self: *MockProvider = @ptrCast(@alignCast(ptr));
        const display_map = self.display_map;
        display_map.deinit();
        self.initialized = false;
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
const t_alloc = std.testing.allocator;

var testlist = [_]Command{
    .goWest,
    .quit,
};
const mock_config: MockProvider.MockConfig = .{ .allocator = t_alloc, .maxx = 40, .maxy = 60, .commands = &testlist };

test "Basic use of mock provider" {
    var p = try MockProvider.init(mock_config);
    var d = p.provider();
    defer d.deinit();

    d.addMessage("frotz");
}

test "fail to create mock provider" { // First allocation attempt
    var failing = std.testing.FailingAllocator.init(t_alloc, .{ .fail_index = 0 });
    const config: MockProvider.MockConfig = .{ .allocator = failing.allocator(), .maxx = 40, .maxy = 60, .commands = &testlist };

    try std.testing.expectError(error.OutOfMemory, MockProvider.init(config));
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var provider_fields = genFields(Self);

// EOF
