const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Map = @import("level.zig").Map;
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const ActionType = zrogue.ActionType;
const Command = zrogue.Command;
const MapContents = zrogue.MapContents;
const Pos = zrogue.Pos;
const ThingAction = zrogue.ThingAction;
const Thing = @import("thing.zig").Thing;
const MessageLog = @import("message_log.zig").MessageLog;

// ===================
//
// Player: Player abstraction
//
// DOT Player -> Thing [label="implements"]
// DOT Player -> InputProvider [label="receives"]
// DOT Player -> DisplayProvider [label="receives"]
// DOT Player -> std_mem_Allocator [label="receives"]
// DOT Player -> MessageLog [label="contains"]
//
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

    inline fn getCommand(self: *Player) ZrogueError!Command {
        return self.input.getCommand();
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

    inline fn getPos(self: *Player) Pos {
        return self.thing.getPos();
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
    // If known and wall/door/stairs (feature), display it.
    // If blind, don't display it
    // If lit and in current room (line of sight simplification), display it.
    // If known and close, display it
    //
    // TODO probably a better way to do this
    //
    for (0..zrogue.MAPSIZE_Y) |y| {
        for (0..zrogue.MAPSIZE_X) |x| {
            const _x: Pos.Dim = @intCast(x);
            const _y: Pos.Dim = @intCast(y);
            var mc = try map.getChar(_x, _y);
            if ((mc.feature()) and (!try map.isKnown(_x, _y))) {
                mc = MapContents.unknown;
            } else if (Pos.distance(Pos.init(_x, _y), self.getPos()) > 1) {
                mc = MapContents.unknown;
            }
            try self.mvaddch(@intCast(_x), @intCast(_y + 1), mapToChar(mc));
        }
    }

    try self.refresh();

    switch (try self.getCommand()) {
        Command.quit => ret = ThingAction.init(ActionType.QuitAction),
        Command.goWest => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(-1, 0)),
        Command.goEast => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(1, 0)),
        Command.goNorth => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(0, -1)),
        Command.goSouth => ret = ThingAction.init_pos(ActionType.BumpAction, Pos.init(0, 1)),
        Command.ascend => ret = ThingAction.init(ActionType.AscendAction),
        Command.descend => ret = ThingAction.init(ActionType.DescendAction),
        else => ret = ThingAction.init(ActionType.NoAction),
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
    var mi = MockInputProvider.init(.{ .commands = &.{} });
    const input = mi.provider();

    const player = try Player.init(std.testing.allocator, input, display);
    defer player.deinit();
}

test "fail to create a player" { // First allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .commands = &.{} });
    const input = mi.provider();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), input, display));
}

test "fail to fully create a player" { // right now there are two allocations
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .commands = &.{} });
    const input = mi.provider();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), input, display));
}

// EOF
