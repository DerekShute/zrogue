//!
//! Everything PLAYER
//!
//! Embeds the Thing interface for a C-like trick that will certainly earn
//! me much derision.
//!
//! The game design is that to figure out the action for this Thing you come
//! here, and this will delegate aspects to display/input providers.
//!

const std = @import("std");
const Grid = @import("utils/grid.zig").Grid;
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const Provider = @import("Provider.zig");
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;

const Command = zrogue.Command;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;
const Region = zrogue.Region;
const ThingAction = zrogue.ThingAction;

// ===================
//
// Player knowledge of map
//
const MapViewTile = struct {
    flags: packed struct {
        known: bool,
    },
};

const MapView = Grid(MapViewTile);

// ===================
//
// Player: Player abstraction
//
pub const Player = struct {
    thing: Thing, // NOTE: Must be first, for pointer coercion from *Thing
    allocator: std.mem.Allocator,
    provider: *Provider = undefined,
    purse: u16 = undefined,
    map_view: MapView = undefined,

    const vtable = Thing.VTable{
        .addMessage = playerAddMessage,
        .getAction = playerGetAction,
        .setKnown = playerSetKnown,
        .takeItem = playerTakeItem,
    };

    pub fn init(allocator: std.mem.Allocator, provider: *Provider, mapsize: Pos) !*Player {
        const p: *Player = try allocator.create(Player);
        errdefer allocator.destroy(p);

        const mapview = try MapView.config(allocator, @intCast(mapsize.getX()), @intCast(mapsize.getY()));
        errdefer mapview.deinit();

        p.allocator = allocator;
        p.purse = 0;
        p.provider = provider;
        p.thing = Thing.config(.player, &vtable);
        p.map_view = mapview;

        return p;
    }

    pub fn deinit(self: *Player) void {
        const allocator = self.allocator;
        const mapview = self.map_view;
        mapview.deinit();
        allocator.destroy(self);
    }

    //
    // Interface: handoff as Thing to anyone who cares
    //
    pub fn toThing(self: *Player) *Thing {
        return &self.thing;
    }

    // REFACTOR: interfaces on top of Thing

    inline fn addMessage(self: *Player, msg: []const u8) void {
        self.provider.addMessage(msg);
    }

    inline fn getCommand(self: *Player) Command {
        return self.provider.getCommand();
    }

    inline fn getPos(self: *Player) Pos {
        return self.thing.getPos();
    }

    inline fn getDistance(self: *Player, pos: Pos) Pos.Dim {
        return self.getPos().distance(pos);
    }

    pub fn getScore(self: *Player) usize {
        const t = self.toThing();
        const i = @as(i32, self.purse * 1000) - t.getMoves();
        return if (i < 0) 0 else @intCast(i);
    }

    pub fn setKnown(self: *Player, p: Pos, known: bool) void {
        var val = self.map_view.find(@intCast(p.getX()), @intCast(p.getY())) catch {
            @panic("Bad pos sent to Player.setKnown"); // THINK: ignore?
        };
        val.flags.known = known;
    }

    pub fn getKnown(self: *Player, p: Pos) bool {
        const val = self.map_view.find(@intCast(p.getX()), @intCast(p.getY())) catch {
            @panic("Bad pos sent to Player.getKnown"); // THINK: ignore?
        };
        return val.flags.known;
    }

    pub fn isVisible(self: *Player, at: Pos) bool {
        // distance <=1 is corner case of standing in a doorway

        if (self.getDistance(at) <= 1) {
            return true;
        }
        return self.toThing().isVisible(at);
    }
};

//
// ugly logic to figure out what is displayed at that location given
// distance-from-player, light, etc.
//
// * If known and wall/door/stairs (feature), display it.
// * FUTURE: If blind, don't display it
// * If lit and in current room (line of sight simplification), display it.
// * If known and close, display it
//
fn render(map: *Map, player: *Player, x: Pos.Dim, y: Pos.Dim) !MapTile {
    const loc = Pos.init(x, y);
    const f_tile = try map.getFloorTile(loc);

    // If you can (not) see it
    if (!player.isVisible(loc)) {
        // ...but you know about it
        if (f_tile.isFeature() and player.getKnown(loc)) {
            return f_tile;
        }

        return .unknown;
    }

    const m_tile = try map.getMonsterTile(loc);
    const i_tile = try map.getItemTile(loc);

    // Otherwise, monster > item > floor
    if (m_tile != .unknown) {
        return m_tile;
    }
    if (i_tile != .unknown) {
        return i_tile;
    }

    return f_tile;
}

fn updateDisplay(p: *Player, map: *Map) !void {
    // FUTURE: this is inefficient.  Only need to send what could have
    //   changed or what did change.  At the very least, set up a bounding
    //   box to iterate through.

    const provider = p.provider;

    provider.updateStats(.{ .depth = map.getDepth(), .purse = p.purse });

    // Send visible map
    for (0..@intCast(map.getHeight())) |y| {
        for (0..@intCast(map.getWidth())) |x| {
            const t = try render(map, p, @intCast(x), @intCast(y));
            try provider.setTile(@intCast(x), @intCast(y), t);
        }
    }
}

//
// Vtable callbacks
//
// playerXX by convention
//

fn playerAddMessage(ptr: *Thing, msg: []const u8) void {
    const self: *Player = @ptrCast(@alignCast(ptr));
    self.addMessage(msg);
}

fn playerGetAction(ptr: *Thing, map: *Map) ZrogueError!ThingAction {
    const self: *Player = @ptrCast(@alignCast(ptr));

    updateDisplay(self, map) catch unreachable; // TODO

    return switch (self.getCommand()) {
        .help => ThingAction.init(.none),
        .quit => ThingAction.init(.quit),
        .goNorth => ThingAction.init_dir(.move, .north),
        .goEast => ThingAction.init_dir(.move, .east),
        .goSouth => ThingAction.init_dir(.move, .south),
        .goWest => ThingAction.init_dir(.move, .west),
        .ascend => ThingAction.init(.ascend),
        .descend => ThingAction.init(.descend),
        .search => ThingAction.init(.search),
        .takeItem => ThingAction.init_pos(.take, self.getPos()),
        else => ThingAction.init(.wait),
    };
}

fn playerSetKnown(ptr: *Thing, r: Region, val: bool) void {
    const self: *Player = @ptrCast(@alignCast(ptr));
    var _r = r; // Resolve const
    var ri = _r.iterator();
    while (ri.next()) |pos| {
        self.setKnown(pos, val);
    }
}

fn playerTakeItem(ptr: *Thing, item: *Item, map: *Map) void {
    const self: *Player = @ptrCast(@alignCast(ptr));

    self.addMessage("You pick up the gold!");
    map.removeItem(item) catch unreachable;
    self.purse = self.purse + 1; // TODO 2.0: quantity/value
}

//
// Unit Tests
//

const MockProvider = @import("Provider.zig").MockProvider;
const expect = std.testing.expect;
const t_alloc = std.testing.allocator;

const Room = @import("map.zig").Room;
const mapgen = @import("mapgen/mapgen.zig");
const test_mapsize = Pos.init(30, 30);
const mock_config: MockProvider.MockConfig = .{ .allocator = t_alloc, .maxx = test_mapsize.getX(), .maxy = test_mapsize.getY(), .commands = &.{} };

test "create a player" {
    var m = try MockProvider.init(mock_config);
    var mp = m.provider();
    defer mp.deinit();
    const player = try Player.init(t_alloc, mp, test_mapsize);
    defer player.deinit();

    //
    // Try out rendering
    //
    var map = try Map.init(t_alloc, test_mapsize.getX(), test_mapsize.getY(), 1, 1);
    defer map.deinit();

    // TODO: Player.move() wrapper

    const p_t = player.toThing();
    try p_t.move(map, Pos.init(6, 6));

    var room = Room.config(Pos.init(5, 5), Pos.init(20, 20));
    room.setDark();
    mapgen.addRoom(map, room);

    // TODO Future: light, blindness

    // distant default
    try expect(try render(map, player, 0, 0) == .unknown);
    // near stuff, including self
    try expect(try render(map, player, 6, 6) == .player);
    try expect(try render(map, player, 5, 5) == .wall);
    try expect(try render(map, player, 7, 7) == .floor);
    // distant 'known' floor not rendered
    player.setKnown(Pos.init(10, 10), true);
    try expect(try render(map, player, 10, 10) == .unknown);
    // distant unknown feature
    try expect(try render(map, player, 20, 20) == .unknown);
    // distant known feature
    player.setKnown(Pos.init(19, 20), true);
    try expect(try render(map, player, 19, 20) == .wall);
}

test "fail to create a player" { // First allocation attempt
    var failing = std.testing.FailingAllocator.init(t_alloc, .{ .fail_index = 0 });
    var m = try MockProvider.init(mock_config);
    var mp = m.provider();
    defer mp.deinit();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), mp, test_mapsize));
}

test "fail to fully create a player" { // right now there are two allocations
    var failing = std.testing.FailingAllocator.init(t_alloc, .{ .fail_index = 1 });
    var m = try MockProvider.init(mock_config);
    var mp = m.provider();
    defer mp.deinit();

    try std.testing.expectError(error.OutOfMemory, Player.init(failing.allocator(), mp, test_mapsize));
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var player_fields = genFields(Player);

// EOF
