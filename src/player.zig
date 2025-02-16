const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Map = @import("map.zig").Map;
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const ActionType = zrogue.ActionType;
const Command = zrogue.Command;
const MapTile = zrogue.MapTile;
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
        p.thing = Thing.config(0, 0, MapTile.player, playerAction, log);
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

    inline fn getDistance(self: *Player, pos: Pos) Pos.Dim {
        return self.getPos().distance(pos);
    }
};

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
// ugly logic to figure out what is displayed at that location given
// distance-from-player, light, etc.
//
// * If known and wall/door/stairs (feature), display it.
// * If blind, don't display it
// * If lit and in current room (line of sight simplification), display it.
// * If known and close, display it
//
fn render(map: *Map, player: *Player, x: Pos.Dim, y: Pos.Dim) !MapTile {
    const tile = try map.getTile(x, y);
    if (tile.feature() and try map.isKnown(x, y)) {
        return tile;
    } else if (player.getDistance(Pos.init(x, y)) <= 1) {
        return tile;
    }
    return MapTile.unknown;
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

    for (0..@intCast(map.getWidth())) |x| {
        if (x < message.len) {
            try self.mvaddch(@intCast(x), 0, message[x]);
        } else {
            try self.mvaddch(@intCast(x), 0, ' ');
        }
    }

    self.clearMessage();

    //
    // Convert map to display
    //
    for (0..@intCast(map.getHeight())) |y| {
        for (0..@intCast(map.getWidth())) |x| {
            const mc = try render(map, self, @intCast(x), @intCast(y));

            // Shift down one row to make room for message bar
            try self.mvaddch(@intCast(x), @intCast(y + 1), mapToChar(mc));
        }
    }

    if (map.inRoom(self.getPos()) and map.isLit(self.getPos())) {
        for (0..zrogue.MAPSIZE_Y) |y| {
            for (0..zrogue.MAPSIZE_X) |x| {
                const _x: Pos.Dim = @intCast(x);
                const _y: Pos.Dim = @intCast(y);
                const tile = try map.getTile(_x, _y);
                try self.mvaddch(@intCast(_x), @intCast(_y + 1), mapToChar(tile));
            }
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
const expect = std.testing.expect;
const Room = @import("map.zig").Room;

test "create a player" {
    var md = MockDisplayProvider.init(.{ .maxx = 20, .maxy = 20 });
    const display = md.provider();
    var mi = MockInputProvider.init(.{ .commands = &.{} });
    const input = mi.provider();

    const player = try Player.init(std.testing.allocator, input, display);
    defer player.deinit();

    //
    // Try out rendering
    //
    var map: Map = try Map.config(std.testing.allocator, 30, 30);
    defer map.deinit();

    try map.setMonster(player.toThing(), 6, 6);

    var room = Room.config(Pos.init(5, 5), Pos.init(20, 20));
    room.setDark();
    try map.addRoom(room);

    // TODO: light, blindness

    // distant default
    try expect(try render(&map, player, 0, 0) == MapTile.unknown);
    // near stuff, including self
    try expect(try render(&map, player, 6, 6) == MapTile.player);
    try expect(try render(&map, player, 5, 5) == MapTile.wall);
    try expect(try render(&map, player, 7, 7) == MapTile.floor);
    // distant 'known' floor not rendered
    try map.setKnown(10, 10, true);
    try expect(try render(&map, player, 10, 10) == MapTile.unknown);
    // distant unknown feature
    try expect(try render(&map, player, 20, 20) == MapTile.unknown);
    // distant known feature
    try map.setKnown(19, 20, true);
    try expect(try render(&map, player, 19, 20) == MapTile.wall);
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
