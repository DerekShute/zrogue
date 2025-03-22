const std = @import("std");
const zrogue = @import("../zrogue.zig");
const map = @import("../map.zig");

const Map = map.Map;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;
const Region = zrogue.Region;
const Room = map.Room;
const Thing = @import("../thing.zig").Thing;
const ZrogueError = zrogue.ZrogueError;

//
// Encapsulate arguments
//

pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
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
    // assumes start.x <= end_x
    for (@intCast(start.getX())..@intCast(end_x + 1)) |x| {
        try m.setTile(@intCast(x), start.getY(), tile);
    }
}

pub fn drawVertLine(m: *Map, start: Pos, end_y: Pos.Dim, tile: MapTile) !void {
    // assumes start.y <= end_y
    for (@intCast(start.getY())..@intCast(end_y + 1)) |y| {
        try m.setTile(start.getX(), @intCast(y), tile);
    }
}

pub fn drawField(m: *Map, start: Pos, limit: Pos, tile: MapTile) !void {
    // assumes start.x <= limit.x and start.y <= limit.y
    var r = try Region.config(start, limit);
    var ri = r.iterator();
    while (ri.next()) |pos| {
        try m.setTile(pos.getX(), pos.getY(), tile);
    }
}

// Rooms

pub fn addRoom(m: *Map, room: Room) ZrogueError!void {
    var r = room; // slide to non-const
    try m.addRoom(r);

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

// TODO: common functions...
// * dig corridor given endpoint and some point in the middle
// * locate a place for a door
// * draw a maze

//
// Unit tests
//

const expect = std.testing.expect;

test "mapgen smoke test" {
    var m = try Map.init(std.testing.allocator, 100, 50, 1, 1);
    defer m.deinit();

    const r = try Room.config(Pos.init(10, 10), Pos.init(20, 20));
    try addRoom(m, r);

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

// EOF
