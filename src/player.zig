const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const MessageLog = @import("message_log.zig").MessageLog;
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");

const ZrogueError = zrogue.ZrogueError;
const ActionType = zrogue.ActionType;
const Command = zrogue.Command;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;
const ThingAction = zrogue.ThingAction;

// ===================
//
// Player: Player abstraction
//
pub const Player = struct {
    thing: Thing, // NOTE: Must be first, for pointer coercion from *Thing
    allocator: std.mem.Allocator,
    input: InputProvider = undefined,
    display: DisplayProvider = undefined,
    log: *MessageLog,
    purse: u16,

    const vtable = Thing.VTable{
        .getAction = playerGetAction,
        .addMessage = playerAddMessage,
        .takeItem = playerTakeItem,
    };

    pub fn init(allocator: std.mem.Allocator, input: InputProvider, display: DisplayProvider) !*Player {
        const p: *Player = try allocator.create(Player);
        errdefer allocator.destroy(p);
        const log = try MessageLog.init(allocator);
        errdefer log.deinit();

        p.allocator = allocator;
        p.purse = 0;
        p.thing = Thing.config(.player, &vtable);
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

    inline fn mvaddstr(self: *Player, x: u16, y: u16, s: []const u8) ZrogueError!void {
        try self.display.mvaddstr(x, y, s);
    }

    inline fn setDisplayTile(self: *Player, x: u16, y: u16, t: MapTile) ZrogueError!void {
        try self.display.setTile(x, y, t);
    }

    inline fn getCommand(self: *Player) ZrogueError!Command {
        return self.input.getCommand();
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
    if (tile.isFeature() and try map.isKnown(x, y)) {
        return tile;
    } else if (player.getDistance(Pos.init(x, y)) <= 1) {
        return tile;
    }
    return .unknown;
}

fn displayHelp(p: *Player) !void {
    // REFACTOR : This is horrible
    // TODO: pull in command keys from input provider?
    try p.mvaddstr(0, 0, "                                                 ");
    try p.mvaddstr(0, 1, "         Welcome to the Dungeon of Doom          ");
    try p.mvaddstr(0, 2, "                                                 ");
    try p.mvaddstr(0, 3, " Use the arrow keys to move through the dungeon  ");
    try p.mvaddstr(0, 4, " and collect gold.  You can only return to the   ");
    try p.mvaddstr(0, 5, " surface after you have descended to the bottom. ");
    try p.mvaddstr(0, 6, "                                                 ");
    try p.mvaddstr(0, 7, " Commands include:                               ");
    try p.mvaddstr(0, 8, "    ? - help (this)                              ");
    try p.mvaddstr(0, 9, "    > - descend stairs (\">\")                   ");
    try p.mvaddstr(0, 10, "    < - ascend stairs (\"<\")                   ");
    try p.mvaddstr(0, 11, "    , - pick up gold  (\"$\")                   ");
    try p.mvaddstr(0, 12, "    q - chicken out and quit                    ");
    try p.mvaddstr(0, 13, "                                                ");
    try p.mvaddstr(0, 14, " [type a command or any other key to continue]  ");
    try p.mvaddstr(0, 15, "                                                ");
    try p.refresh();
}

fn displayScreen(p: *Player, map: *Map) !void {
    const message = p.getMessage();

    for (0..@intCast(map.getWidth())) |x| {
        if (x < message.len) {
            try p.mvaddch(@intCast(x), 0, message[x]);
        } else {
            try p.mvaddch(@intCast(x), 0, ' ');
        }
    }

    p.clearMessage();

    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)

    var stats: [80]u8 = undefined; // does this need to be allocated?  size?

    // We know that error.NoSpaceLeft can't happen here
    const line = std.fmt.bufPrint(&stats, "Level: {}  Gold: {:<5}  Hp: some", .{ map.getDepth(), p.purse }) catch unreachable;

    for (0.., line) |x, c| {
        try p.mvaddch(@intCast(x), @intCast(map.getHeight() + 1), c);
    }

    //
    // Convert map to display
    //
    // Shift down one row to make room for message bar
    //
    for (0..@intCast(map.getHeight())) |y| {
        for (0..@intCast(map.getWidth())) |x| {
            const t = try render(map, p, @intCast(x), @intCast(y));

            try p.setDisplayTile(@intCast(x), @intCast(y + 1), t);
        }
    }

    if (map.inRoom(p.getPos()) and map.isLit(p.getPos())) {
        var r = map.getRoomRegion(p.getPos()) catch unreachable; // Known
        var ri = r.iterator();

        while (ri.next()) |pos| {
            const x = pos.getX();
            const y = pos.getY();
            const tile = try map.getTile(x, y);
            try p.setDisplayTile(@intCast(x), @intCast(y + 1), tile);
        }
    }

    try p.refresh();
}

//
// Vtable callbacks
//
// playerXX by convention
//

fn playerAddMessage(ptr: *Thing, msg: []const u8) void {
    const self: *Player = @ptrCast(@alignCast(ptr));
    self.log.add(msg);
}

fn playerGetAction(ptr: *Thing, map: *Map) !ThingAction {
    // Map is the _visible_ or _known_ map presented to the player

    const self: *Player = @ptrCast(@alignCast(ptr));
    var ret = ThingAction.init(ActionType.NoAction);

    try displayScreen(self, map);

    var cmd = try self.getCommand();
    while (cmd == .help) {
        try displayHelp(self);
        cmd = try self.getCommand();
    }
    ret = switch (cmd) {
        .help => ThingAction.init(.NoAction),
        .quit => ThingAction.init(.QuitAction),
        .goWest => ThingAction.init_pos(.MoveAction, Pos.init(-1, 0)),
        .goEast => ThingAction.init_pos(.MoveAction, Pos.init(1, 0)),
        .goNorth => ThingAction.init_pos(.MoveAction, Pos.init(0, -1)),
        .goSouth => ThingAction.init_pos(.MoveAction, Pos.init(0, 1)),
        .ascend => ThingAction.init(.AscendAction),
        .descend => ThingAction.init(.DescendAction),
        .takeItem => ThingAction.init_pos(.TakeAction, self.getPos()),
        else => ThingAction.init(.WaitAction),
    };

    return ret;
}

fn playerTakeItem(ptr: *Thing, item: *Item, map: *Map) void {
    const self: *Player = @ptrCast(@alignCast(ptr));

    self.log.add("You pick up the gold!");
    map.removeItem(item);
    self.purse = self.purse + 1; // TODO quantity/value
}

//
// Unit Tests
//

const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
const MockInputProvider = @import("input.zig").MockInputProvider;
const expect = std.testing.expect;
const Room = @import("map.zig").Room;
const mapgen = @import("mapgen/mapgen.zig");

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
    var map = try Map.init(std.testing.allocator, 30, 30, 1, 1);
    defer map.deinit();

    try map.setMonster(player.toThing(), 6, 6);

    var room = Room.config(Pos.init(5, 5), Pos.init(20, 20));
    room.setDark();
    mapgen.addRoom(map, room);

    // TODO: light, blindness

    // distant default
    try expect(try render(map, player, 0, 0) == .unknown);
    // near stuff, including self
    try expect(try render(map, player, 6, 6) == .player);
    try expect(try render(map, player, 5, 5) == .wall);
    try expect(try render(map, player, 7, 7) == .floor);
    // distant 'known' floor not rendered
    try map.setKnown(10, 10, true);
    try expect(try render(map, player, 10, 10) == .unknown);
    // distant unknown feature
    try expect(try render(map, player, 20, 20) == .unknown);
    // distant known feature
    try map.setKnown(19, 20, true);
    try expect(try render(map, player, 19, 20) == .wall);
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

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var player_fields = genFields(Player);

// EOF
