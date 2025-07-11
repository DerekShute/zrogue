//!
//! input/output Provider, plus Mock for testing
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const Grid = @import("utils/grid.zig").Grid;
const MessageLog = @import("message_log.zig").MessageLog;
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
display_map: DisplayMap = undefined,
stats: VisibleStats = undefined,
x: i16 = 0,
y: i16 = 0,
log: *MessageLog = undefined,

//
// Constructor and destructor
//

pub inline fn deinit(self: Self) void {
    self.display_map.deinit();
    self.log.deinit();
    self.vtable.deinit(self.ptr);
}

//
// Methods
//

pub inline fn addMessage(self: Self, msg: []const u8) void {
    self.log.add(msg);
}

pub inline fn getMessage(self: Self) []u8 {
    return self.log.get();
}

pub inline fn clearMessage(self: Self) void {
    self.log.clear();
}

pub fn setTile(self: Self, x: u16, y: u16, t: MapTile) Error!void {
    var val = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: ignore?
    };
    val.tile = t;
}

pub fn updateStats(self: *Self, stats: VisibleStats) void {
    self.stats = stats;
}

pub inline fn getCommand(self: Self) Command {
    return self.vtable.getCommand(self.ptr);
}

//
// MockProvider for testing purposes
//

pub const MockProvider = struct {
    allocator: std.mem.Allocator,
    command_list: []Command = undefined,
    command_index: u16 = 0,
    p: Self = undefined,

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

        const log = try MessageLog.init(config.allocator);
        errdefer log.deinit();

        return MockProvider{
            .allocator = config.allocator,
            .command_list = config.commands,
            .p = .{
                .log = log,
                .ptr = undefined,
                .display_map = display_map,
                .x = config.maxx,
                .y = config.maxy,
                .vtable = &.{
                    .deinit = mock_deinit,
                    .getCommand = mock_getCommand,
                },
            },
        };
    }

    pub fn provider(self: *MockProvider) *Self {
        self.p.ptr = self;
        return &self.p;
    }

    //
    // Methods
    //

    fn mock_deinit(ptr: *anyopaque) void {
        _ = ptr;
        return;
    }

    fn mock_getCommand(ptr: *anyopaque) Command {
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

const expectError = std.testing.expectError;
const t_alloc = std.testing.allocator;

var testlist = [_]Command{
    .go_west,
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
