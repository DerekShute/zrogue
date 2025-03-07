const std = @import("std");
const zrogue = @import("zrogue.zig");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const randomizer = @import("random.zig");
const Room = @import("map.zig").Room;
const Thing = @import("thing.zig").Thing;

const Randomizer = randomizer.Randomizer;
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;

// Minimum non-gone room size: 2x2 not including walls
const MINX = 4;
const MINY = 4;

//
// Level generation from the top
//

fn makeRogueRoom(roomno: i16, map: *Map, r: Randomizer) !Room {
    // "room number" is gross

    // Size of bounding box

    const maxxsize = @divTrunc(map.width, map.roomsx);
    const maxysize = @divTrunc(map.height, map.roomsy);

    // Find upper left corner of the box

    const topx = @mod(roomno, map.roomsx) * maxxsize;
    const topy = @divTrunc(roomno, map.roomsy) * maxysize;

    // TODO: gone room

    // TODO: dark
    // TOOD: maze

    const maxx = r.roll(@intCast(maxxsize - MINX)) + MINX - 1;
    const maxy = r.roll(@intCast(maxysize - MINY)) + MINY - 1;
    const xpos = topx + r.roll(@intCast(maxxsize - maxx));
    const ypos = topy + r.roll(@intCast(maxysize - maxy));

    return Room.config(Pos.init(xpos, ypos), Pos.init(xpos + maxx, ypos + maxy));
}

fn isRoomAdjacent(width: i16, i: i16, j: i16) bool {
    if ((j == i + 1) or (j == i - 1)) {
        // left or right, same row
        return true;
    } else if ((j == i + width) or (j == i - width)) {
        // same column, up or down
        return true;
    }
    return false;
}

// ========================================================
//
// Public/interface routines
//

// Encapsulate arguments
pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    random: Randomizer = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
    xRooms: Pos.Dim = -1,
    yRooms: Pos.Dim = -1,
};

//
// Fixed things at fixed locations for deterministic behavior
//
fn createTestLevel(config: LevelConfig) !*Map {
    var map = try Map.init(config.allocator, config.xSize, config.ySize, config.xRooms, config.yRooms);
    errdefer map.deinit();

    var room = try Room.config(Pos.init(2, 2), Pos.init(9, 9));
    room.setDark();
    try map.addRoom(room);

    try map.addRoom(try Room.config(Pos.init(27, 5), Pos.init(35, 10)));
    try map.dig(Pos.init(9, 5), Pos.init(27, 8));

    try map.addRoom(try Room.config(Pos.init(4, 12), Pos.init(20, 19)));
    try map.dig(Pos.init(4, 9), Pos.init(18, 12));

    try map.addItem(Item.config(10, 16, .gold));

    if (config.player) |p| {
        try map.setMonster(p, 6, 6);
    }

    return map;
}

// TODO: destructor

pub const createLevel = createTestLevel;

//
// Randomly-generated level
//

pub fn createRogueLevel(config: LevelConfig) !*Map {
    const MAX_EVER = 99;
    var map = try Map.init(config.allocator, config.xSize, config.ySize, config.xRooms, config.yRooms);
    errdefer map.deinit();

    const maxrooms = config.xRooms * config.yRooms;

    // For all rooms
    //  * create room
    //  * place gold
    //  * place monster

    // Connect passages

    // TODO if >= MAX_EVER then error
    var ingraph = [_]bool{0} ** MAX_EVER; // Rooms connected to graph

    // connection graph is [i][j] = bool and you need to set connections
    // such that if X connects Y, then Y connects X

    // Count connections themselves?  For 3x3 this is 12

    return map;
}

//
// Unit tests
//

const expect = std.testing.expect;
const tallocator = std.testing.allocator;

test "use test level" {
    // TODO need mock Thing
    const config = LevelConfig{
        .allocator = tallocator,
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
        .xRooms = zrogue.ROOMS_X,
        .yRooms = zrogue.ROOMS_Y,
    };

    const map = try createTestLevel(config);
    defer map.deinit();
}

test "rogue room minimums" {
    var rng = randomizer.FixedPrng.init();
    const random = rng.random();
    const r = Randomizer.config(random);

    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit();

    rng.value = 0;
    for (0..3) |y| {
        for (0..3) |x| {
            const i: i16 = @intCast(y * 3 + x);
            var room = try makeRogueRoom(i, map, r);

            try expect(room.getMinX() == x * 26);
            try expect(room.getMaxX() == x * 26 + 3);
            try expect(room.getMinY() == y * 8);
            try expect(room.getMaxY() == y * 8 + 3);
        }
    }
}

// Apparently can't embed these in the test block

fn testsTrue(i: i16, j: i16) !void {
    try expect(isRoomAdjacent(3, i, j) == true);
    try expect(isRoomAdjacent(3, j, i) == true);
}

fn testsFalse(i: i16, j: i16) !void {
    try expect(isRoomAdjacent(3, i, j) == false);
    try expect(isRoomAdjacent(3, j, i) == false);
}

test "room adjacency" {
    try testsTrue(0, 3);
    try testsTrue(0, 1);
    try testsTrue(4, 5);
    try testsTrue(4, 3);
    try testsFalse(0, 2);
    try testsFalse(0, 4);
    try testsFalse(0, 8);
}

// Boundary testing
//
// Uses actual randomness and then tests expectations and limits
//
// TODO this belongs in a separate test suite

test "rogue room boundary" {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const random = prng.random();
    const r = Randomizer.config(random);

    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit();

    for (0..3) |y| {
        for (0..3) |x| {
            const i: i16 = @intCast(y * 3 + x);
            var room = try makeRogueRoom(i, map, r);

            try expect(room.getMinX() >= x * 26);
            try expect(room.getMaxX() >= x * 26 + 3);
            try expect(room.getMinY() >= y * 8);
            try expect(room.getMaxY() >= y * 8 + 3);
        }
    }
}
// EOF
