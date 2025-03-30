const std = @import("std");
const mapgen = @import("mapgen.zig");
const Map = @import("../map.zig").Map;
const Room = @import("../map.zig").Room;
const Pos = @import("../zrogue.zig").Pos;

// Constants that this mapgen relies on

const min_room_dim = 4; // min non-gone room size: 2x2 not including walls
const rooms_dim = 3; // 3x3 grid of room 'spots'
const max_rooms = rooms_dim * rooms_dim;

//
// Utilities
//

fn makeRogueRoom(roomno: i16, map: *Map, r: *std.Random) !Room {
    // Size of bounding box and its upper left corner
    const max_xsize = @divTrunc(map.getWidth(), rooms_dim);
    const max_ysize = @divTrunc(map.getHeight(), rooms_dim);
    const topx = @mod(roomno, rooms_dim) * max_xsize;
    const topy = @divTrunc(roomno, rooms_dim) * max_ysize;

    // TODO: gone room
    // TODO: dark
    // TODO: maze

    // The room size must leave one block on the East and South edges for
    // corridors, and this must be reflected in the positioning logic, so
    // always max_#size - 1

    const xlen = r.intRangeAtMost(Pos.Dim, min_room_dim, max_xsize - 1);
    const ylen = r.intRangeAtMost(Pos.Dim, min_room_dim, max_ysize - 1);
    const xpos = topx + r.intRangeAtMost(Pos.Dim, 0, max_xsize - 1 - xlen);
    const ypos = topy + r.intRangeAtMost(Pos.Dim, 0, max_ysize - 1 - ylen);

    std.debug.print("room {}: @ {},{} size {}x{} of {}x{}\n", .{ roomno, xpos, ypos, xlen, ylen, max_xsize, max_ysize });

    const tl = Pos.init(xpos, ypos);
    const br = Pos.init(xpos + xlen - 1, ypos + ylen - 1);
    return Room.config(tl, br);
}

// TODO: this is partially redundant
// TODO: into Map?  It assumes a room grid
fn isRoomAdjacent(i: i16, j: i16) bool {
    const i_row = @divTrunc(i, rooms_dim);
    const j_row = @divTrunc(j, rooms_dim);
    const i_col = @mod(i, rooms_dim);
    const j_col = @mod(j, rooms_dim);

    if (i_row == j_row) { // neighbors, same row
        // TODO subtract, absolute value
        return if ((i == j + 1) or (j == i + 1)) true else false;
    } else if (i_col == j_col) { // neighbors, same column
        return if ((i_row == j_row + 1) or (j_row == i_row + 1)) true else false;
    }
    return false;
}

// Connection graph between rooms

fn setConnected(graph: []bool, r1: usize, r2: usize) void {
    graph[r1 * max_rooms + r2] = true;
    graph[r2 * max_rooms + r1] = true;
}

fn isConnected(graph: []bool, r1: i16, r2: i16) bool {
    return graph[r1 * max_rooms + r2];
}

// Dig a passage

fn connectRooms(map: *Map, rn1: usize, rn2: usize, r: *std.Random) !void {
    const i = @min(rn1, rn2); // Western or Northern
    const j = @max(rn1, rn2); // Eastern or Southern
    var r1 = map.rooms[i]; // TODO huge ugh
    var r2 = map.rooms[j];

    // Pick valid connection points (along the opposite room sides, not on
    // the corners, and a location for the midpoint)

    if (j == i + 1) { // Eastward dig
        const r1_x = r1.getMaxX();
        const r1_y = r.intRangeAtMost(Pos.Dim, r1.getMinY() + 1, r1.getMaxY() - 1);
        const r2_x = r2.getMinX();
        const r2_y = r.intRangeAtMost(Pos.Dim, r2.getMinY() + 1, r2.getMaxY() - 1);
        const mid = r.intRangeAtMost(Pos.Dim, r1_x + 1, r2_x - 1);
        std.debug.print("Connecting {}-{} at {},{}-{},{} mid {}\n", .{ rn1, rn2, r1_x, r1_y, r2_x, r2_y, mid });
        try mapgen.addEastCorridor(map, Pos.init(r1_x, r1_y), Pos.init(r2_x, r2_y), mid);
    } else { // Southward dig
        const r1_x = r.intRangeAtMost(Pos.Dim, r1.getMinX() + 1, r1.getMaxX() - 1);
        const r1_y = r1.getMaxY();
        const r2_x = r.intRangeAtMost(Pos.Dim, r2.getMinX() + 1, r2.getMaxX() - 1);
        const r2_y = r2.getMinY();
        const mid = r.intRangeAtMost(Pos.Dim, r1_y + 1, r2_y - 1);
        std.debug.print("Connecting {}-{} at {},{}-{},{} mid {}\n", .{ rn1, rn2, r1_x, r1_y, r2_x, r2_y, mid });
        try mapgen.addSouthCorridor(map, Pos.init(r1_x, r1_y), Pos.init(r2_x, r2_y), mid);
    }
}

// ========================================================
//
// Mapgen interface: create a level using the traditional Rogue
// algorithms
//

pub fn createRogueLevel(config: mapgen.LevelConfig) !*Map {
    var ingraph = [_]bool{false} ** max_rooms; // Rooms connected to graph
    var connections = [_]bool{false} ** (max_rooms * max_rooms);
    var map = try Map.init(config.allocator, config.xSize, config.ySize, rooms_dim, rooms_dim);
    errdefer map.deinit();

    // TODO: select gone rooms and deal with those

    for (0..max_rooms) |i| {
        const room = try makeRogueRoom(@intCast(i), map, config.rand);

        // TODO: place gold
        // TODO: place monster
        try mapgen.addRoom(map, room);
    }

    // Connect passages
    // TODO: list of rooms, shuffled

    var r1: usize = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
    ingraph[r1] = true;
    var roomcount: usize = 1;

    // Find an adjacent room to connect with

    while (roomcount < max_rooms) {
        var j: usize = 0;
        var r2: usize = 1000;
        for (0..max_rooms) |i| {
            if (isRoomAdjacent(@intCast(r1), @intCast(i))) {
                if (!ingraph[i]) { // Not considered yet
                    j += 1;
                    // was some roll vs 0 and j here
                    r2 = @intCast(i);
                    break;
                }
            }
        }
        if (r2 < 1000) {
            // Found adjacent room not already in graph
            ingraph[@intCast(r2)] = true;
            try connectRooms(map, r1, r2, config.rand);
            setConnected(&connections, @intCast(r1), @intCast(r2));
            roomcount += 1;
        } else {
            // No adjacent rooms outside of graph: start over with a new room
            r1 = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
            while (ingraph[r1] == false) {
                r1 = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
            }
        }
    } // While roomcount < max_rooms

    // TODO: Add passages randomly some number of times
    // If not connected

    // TODO: keep track of map.passages[] for some reason

    // TODO: find valid location for player
    if (config.player) |p| {
        try map.setMonster(p, 8, 3);
    }

    return map;
}

//
// Unit tests
//

const expect = std.testing.expect;
const tallocator = std.testing.allocator;

// Adjacency tests
//
// Apparently can't embed these in the test block

fn testsTrue(i: i16, j: i16) !void {
    try expect(isRoomAdjacent(i, j) == true);
    try expect(isRoomAdjacent(j, i) == true);
}

fn testsFalse(i: i16, j: i16) !void {
    try expect(isRoomAdjacent(i, j) == false);
    try expect(isRoomAdjacent(j, i) == false);
}

test "room adjacency" {
    try testsTrue(0, 3);
    try testsTrue(0, 1);
    try testsTrue(4, 5);
    try testsTrue(4, 3);
    try testsFalse(0, 2);
    try testsFalse(0, 4);
    try testsFalse(0, 5);
    try testsFalse(0, 7);
    try testsFalse(0, 8);
    try testsFalse(2, 3);
}

// Room creation

test "rogue rooms" {
    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit();

    // This is of course very carefully crafted to pass
    const xroomsize = 26;
    const yroomsize = 8;
    const xsize = 7;
    const ysize = 7;
    const xoffset = 9;
    const yoffset = 0;

    for (0..rooms_dim) |y| {
        for (0..rooms_dim) |x| {
            var prng = std.Random.DefaultPrng.init(0);
            var r = prng.random();
            const i: i16 = @intCast(y * rooms_dim + x);
            var room = try makeRogueRoom(i, map, &r);
            try expect(room.getMinX() == x * xroomsize + xoffset);
            try expect(room.getMaxX() == x * xroomsize + xoffset + xsize - 1);
            try expect(room.getMinY() == y * yroomsize + yoffset);
            try expect(room.getMaxY() == y * yroomsize + yoffset + ysize - 1);
            try mapgen.addRoom(map, room);
        }
    }
}

test "create Rogue level" {
    var prng = std.Random.DefaultPrng.init(0);
    var r = prng.random();

    const config = mapgen.LevelConfig{
        .allocator = tallocator,
        .rand = &r,
        .xSize = 80,
        .ySize = 24,
        .mapgen = .ROGUE,
    };

    var map = try createRogueLevel(config);
    defer map.deinit();
}

test "fuzz test room generation" {
    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();
    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit();

    for (0..rooms_dim) |y| {
        for (0..rooms_dim) |x| {
            const i: i16 = @intCast(y * rooms_dim + x);
            const room = try makeRogueRoom(i, map, &r);
            try mapgen.addRoom(map, room);
        }
    }
}

// EOF
