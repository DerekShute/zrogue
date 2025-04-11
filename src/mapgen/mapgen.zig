const std = @import("std");
const zrogue = @import("../zrogue.zig");
const map = @import("../map.zig");

const Map = map.Map;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;
const Region = zrogue.Region;
const Room = map.Room;
const Thing = @import("../thing.zig").Thing;

//
// Encapsulate arguments
//

pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    rand: *std.Random = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
    level: usize = 1,
    going_down: bool = true,
    mapgen: enum {
        TEST,
        ROGUE,
    },
};

//
// Published factories
//

pub const createTestLevel = @import("test_level.zig").createTestLevel;
pub const createRogueLevel = @import("rogue_level.zig").createRogueLevel;

//
// Mapgen Utilities
//

pub fn drawHorizLine(m: *Map, start: Pos, end_x: Pos.Dim, tile: MapTile) !void {
    const minx = @min(start.getX(), end_x + 1);
    const maxx = @max(start.getX(), end_x + 1);
    for (@intCast(minx)..@intCast(maxx)) |x| {
        try m.setTile(@intCast(x), start.getY(), tile);
    }
}

pub fn drawVertLine(m: *Map, start: Pos, end_y: Pos.Dim, tile: MapTile) !void {
    const miny = @min(start.getY(), end_y + 1);
    const maxy = @max(start.getY(), end_y + 1);
    for (@intCast(miny)..@intCast(maxy)) |y| {
        try m.setTile(start.getX(), @intCast(y), tile);
    }
}

pub fn drawField(m: *Map, start: Pos, limit: Pos, tile: MapTile) !void {
    // assumes start.x <= limit.x and start.y <= limit.y
    var r = Region.config(start, limit);
    var ri = r.iterator();
    while (ri.next()) |pos| {
        try m.setTile(pos.getX(), pos.getY(), tile);
    }
}

// Rooms

pub fn addRoom(m: *Map, room: Room) void {
    var r = room; // slide to non-const
    m.addRoom(r);

    // The original drew horizontal and vertical bars
    // Fns.vert(map, minx, .{ miny + 1, maxy - 1 });
    // Fns.vert(map, maxx, .{ miny + 1, maxy - 1 });
    // Fns.horiz(map, miny, .{ minx, maxx });
    // Fns.horiz(map, maxy, .{ minx, maxx });

    // Floor

    const s = Pos.init(r.getMinX() + 1, r.getMinY() + 1);
    const e = Pos.init(r.getMaxX() - 1, r.getMaxY() - 1);

    // TODO room shapes and contents

    // source and end are known good because we added the room above

    drawField(m, s, e, .floor) catch unreachable;
}

pub fn getRoom(m: *Map, roomno: usize) *Room {
    // Slightly better than using the raw reference
    if (roomno >= m.rooms.len) {
        @panic("mapgen.getRoom bad room number");
    }
    return &m.rooms[roomno];
}

// Corridors

pub fn addSouthCorridor(m: *Map, start: Pos, end: Pos, mid: Pos.Dim) !void {
    // TODO: the start and end should be validated
    try drawVertLine(m, start, mid, .floor);
    try drawHorizLine(m, Pos.init(start.getX(), mid), end.getX(), .floor);
    try drawVertLine(m, Pos.init(end.getX(), mid), end.getY(), .floor);
}

pub fn addEastCorridor(m: *Map, start: Pos, end: Pos, mid: Pos.Dim) !void {
    // TODO: the start and end should be validated
    try drawHorizLine(m, start, mid, .floor);
    try drawVertLine(m, Pos.init(mid, start.getY()), end.getY(), .floor);
    try drawHorizLine(m, Pos.init(mid, end.getY()), end.getX(), .floor);
}

// TODO: common functions...
// * locate a place for a door
// * draw a maze

//
// Unit tests
//

const expect = std.testing.expect;

test "mapgen smoke test" {
    var m = try Map.init(std.testing.allocator, 100, 50, 1, 1);
    defer m.deinit();

    const r = Room.config(Pos.init(10, 10), Pos.init(20, 20));
    addRoom(m, r);

    try expect(m.isLit(Pos.init(15, 15)) == true);

    try expect(try m.isKnown(15, 15) == false);
    try expect(try m.getTile(0, 0) == .wall);
    try expect(try m.getTile(10, 10) == .wall);

    try m.setKnown(15, 15, true);
    try expect(try m.isKnown(15, 15) == true);
    try m.setKnown(15, 15, false);
    try expect(try m.isKnown(15, 15) == false);

    // Explicit set tile inside a known room
    try m.setTile(17, 17, .wall);
    try expect(try m.getTile(17, 17) == .wall);

    try m.setTile(18, 18, .door);
    try expect(try m.getTile(18, 18) == .door);

    try m.setRegionKnown(12, 12, 15, 15);
    try expect(try m.isKnown(12, 12) == true);
    try expect(try m.isKnown(15, 15) == true);
    try expect(try m.isKnown(16, 16) == false);
    try expect(try m.isKnown(11, 11) == false);
}

// Corridors

test "dig corridors" {
    var m = try Map.init(std.testing.allocator, 40, 40, 2, 2);
    defer m.deinit();

    // These don't have to make sense as part of actual rooms
    // Doors are created by the level generator

    // Eastward dig, southgoing vertical
    try addEastCorridor(m, Pos.init(4, 4), Pos.init(20, 10), 12);
    try expect(try m.getTile(12, 7) == .floor); // halfway
    try expect(try m.getTile(12, 4) == .floor);
    try expect(try m.getTile(12, 10) == .floor);
    try expect(try m.getTile(4, 4) == .floor);
    try expect(try m.getTile(20, 10) == .floor);
    try drawField(m, Pos.init(4, 4), Pos.init(20, 10), .wall); // reset

    // Eastward dig, northgoing vertical
    try addEastCorridor(m, Pos.init(4, 10), Pos.init(20, 4), 12);
    try expect(try m.getTile(12, 7) == .floor); // halfway
    try expect(try m.getTile(12, 4) == .floor);
    try expect(try m.getTile(12, 10) == .floor);
    try expect(try m.getTile(4, 10) == .floor);
    try expect(try m.getTile(20, 4) == .floor);
    try drawField(m, Pos.init(4, 4), Pos.init(20, 10), .wall); // reset

    // Southward dig, westgoing horizontal
    try addSouthCorridor(m, Pos.init(10, 8), Pos.init(3, 14), 11);
    try expect(try m.getTile(6, 11) == .floor); // halfway
    try expect(try m.getTile(3, 11) == .floor);
    try expect(try m.getTile(10, 11) == .floor);
    try expect(try m.getTile(10, 8) == .floor);
    try expect(try m.getTile(3, 14) == .floor);
    try drawField(m, Pos.init(3, 8), Pos.init(10, 14), .wall); // reset

    // Southward dig, eastgoing horizontal
    try addSouthCorridor(m, Pos.init(3, 8), Pos.init(10, 14), 11);
    try expect(try m.getTile(6, 11) == .floor); // halfway
    try expect(try m.getTile(3, 11) == .floor);
    try expect(try m.getTile(10, 11) == .floor);
    try expect(try m.getTile(3, 8) == .floor);
    try expect(try m.getTile(10, 14) == .floor);
    try drawField(m, Pos.init(3, 8), Pos.init(10, 14), .wall); // reset
}

test "dig unusual corridors" {
    var m = try Map.init(std.testing.allocator, 20, 20, 2, 2);
    defer m.deinit();

    // One tile
    try addSouthCorridor(m, Pos.init(5, 10), Pos.init(5, 12), 11);
    try expect(try m.getTile(5, 11) == .floor);

    // straight East
    try addEastCorridor(m, Pos.init(10, 5), Pos.init(15, 5), 12);
    try expect(try m.getTile(11, 5) == .floor);
    try expect(try m.getTile(13, 5) == .floor);
    try expect(try m.getTile(14, 5) == .floor);

    // straight South
    try addSouthCorridor(m, Pos.init(16, 8), Pos.init(16, 13), 10);
    try expect(try m.getTile(16, 9) == .floor);
    try expect(try m.getTile(16, 10) == .floor);
    try expect(try m.getTile(16, 12) == .floor);
}

// EOF
