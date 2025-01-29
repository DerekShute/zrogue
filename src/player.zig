const std = @import("std");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Map = @import("level.zig").Map;
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const MapContents = zrogue.MapContents;
const Thing = @import("thing.zig").Thing;
const MessageLog = @import("message_log.zig").MessageLog;

// ===================
// Player:

pub const Player = struct {
    thing: Thing, // NOTE: Must be first, for pointer coercion from *Thing
    allocator: std.mem.Allocator,
    input: InputProvider = undefined,
    display: DisplayProvider = undefined,
    log: *MessageLog,

    pub fn init(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !*Player {
        const p: *Player = try allocator.create(Player);
        errdefer allocator.destroy(p);
        const log = try MessageLog.init(allocator);
        errdefer log.deinit();

        p.allocator = allocator;
        p.thing = Thing.config(0, 0, MapContents.player, playerAction, log);
        p.input = input;
        p.display = display;
        p.log = log;

        return p;
    }

    pub fn deinit(self: *Player) void {
        const allocator = self.allocator;
        const log = self.log;
        log.deinit();
        allocator.destroy(self);
    }

    //
    // Interface: handoff as Thing to anyone who cares
    //
    pub fn toThing(self: *Player) *Thing {
        return &self.thing;
    }

    // TODO: interfaces on top of Thing
    inline fn refresh(self: *Player) ZrogueError!void {
        try self.display.refresh();
    }

    inline fn mvaddch(self: *Player, x: u16, y: u16, ch: u8) ZrogueError!void {
        try self.display.mvaddch(x, y, ch);
    }

    inline fn getch(self: *Player) ZrogueError!usize {
        return self.input.getch();
    }

    inline fn addMessage(self: *Player, msg: []const u8) void {
        self.log.add(msg);
    }

    inline fn getMessage(self: *Player) []u8 {
        return self.log.get();
    }

    inline fn clearMessage(self: *Player) void {
        return self.log.clear();
    }
};

//
// Convert map location to what it is displayed as
//
fn mapToChar(ch: MapContents) u8 {
    const c: u8 = switch (ch) {
        MapContents.unknown => ' ',
        MapContents.floor => '.',
        MapContents.wall => '#',
        MapContents.player => '@',
    };
    return c;
}

//
// Action callback
//
// Map is the _visible_ or _known_ map presented to the player
//
fn playerAction(ptr: *Thing, map: *Map) !ThingAction {
    const self: *Player = @ptrCast(@alignCast(ptr));
    var ret = ThingAction.init(ActionType.NoAction);
    const message = self.getMessage();

    for (0..zrogue.MAPSIZE_X) |x| {
        if (x < message.len) {
            try self.mvaddch(@intCast(x), 0, message[x]);
        } else {
            try self.mvaddch(@intCast(x), 0, ' ');
        }
    }

    self.clearMessage();

    //
    // Convert map to display: it shifts down one row to make room for
    // messages
    //
    for (0..zrogue.MAPSIZE_Y) |y| {
        for (0..zrogue.MAPSIZE_X) |x| {
            const ch = mapToChar(try map.getChar(@intCast(x), @intCast(y)));
            try self.mvaddch(@intCast(x), @intCast(y + 1), ch);
        }
    }

    try self.refresh();
    const ch = try self.getch();

    switch (ch) {
        'q' => ret = ThingAction.init(ActionType.QuitAction),
        'l' => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(-1, 0)),
        'r' => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(1, 0)),
        else => try self.mvaddch(0, 0, @intCast(ch)),
    }

    return ret;
}

//
// Unit Tests
//

const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
const MockInputProvider = @import("input.zig").MockInputProvider;

test "create a player" {
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .keypress = 'q' });
    const input = mi.provider();

    const player = try Player.init(std.testing.allocator, input, display);
    defer player.deinit();
}

test "fail to create a player" { // First allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .keypress = 'q' });
    const input = mi.provider();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), input, display));
}

test "fail to fully create a player" { // right now there are two allocations
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .keypress = 'q' });
    const input = mi.provider();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), input, display));
}

// EOF
