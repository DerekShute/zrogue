const std = @import("std");
const LevelConfig = @import("mapgen.zig").LevelConfig;
const Map = @import("../map.zig").Map;
const Room = @import("../map.zig").Room;
const Pos = @import("../zrogue.zig").Pos;

// Constants that this mapgen relies on

const min_room_dim = 4; // min non-gone room size: 2x2 not including walls
const rooms_dim = 3; // 3x3 grid of room 'spots'
const max_rooms = rooms_dim * rooms_dim;

// Prototype randomizer / die-roll doodad, currently hammered to return the
// median of inputs

const Randomizer = struct {
    const IntType = u8;

    fn roll(self: Randomizer, maxval: anytype) IntType {
        // TODO: generate random number, minimum, maximum, or median
        _ = self;
        const ret: IntType = @intCast(maxval);
        return @divTrunc(ret, 2);
    }

    // Will be r.roll(maxval - minval) + minval - 1 or something
    fn rollMin(self: Randomizer, minval: anytype, maxval: anytype) IntType {
        // TODO: generate random number, minimum, maximum, or median
        _ = self;
        const ret: IntType = @intCast(minval + maxval);
        return @intCast(@divTrunc(ret, 2));
    }
};

//
// Utilities
//

fn makeRogueRoom(roomno: i16, map: *Map, r: Randomizer) !Room {
    // Size of bounding box and its upper left corner
    const max_xsize = @divTrunc(map.getWidth(), rooms_dim);
    const max_ysize = @divTrunc(map.getHeight(), rooms_dim);
    const topx = @mod(roomno, rooms_dim) * max_xsize;
    const topy = @divTrunc(roomno, rooms_dim) * max_ysize;

    // TODO: gone room
    // TODO: dark
    // TODO: maze

    // TODO: there must be one row/column between all rooms for potential
    // corridors

    const xlen = r.rollMin(min_room_dim, max_xsize - 1);
    const ylen = r.rollMin(min_room_dim, max_ysize - 1);
    const xpos = topx + r.roll(max_xsize - xlen);
    const ypos = topy + r.roll(max_ysize - ylen);

    std.debug.print("room {}: @ {},{} size {}x{}\n", .{ roomno, xpos, ypos, xlen, ylen });

    const tl = Pos.init(xpos, ypos);
    const br = Pos.init(xpos + xlen, ypos + ylen);
    return Room.config(tl, br);
}

// TODO: this is partially redundant
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
// TODO: this is half of Map.dig() and should pull in the rest
fn connectRooms(map: *Map, rn1: usize, rn2: usize) void {
    const i = @min(rn1, rn2); // Western or Northern
    const j = @max(rn1, rn2); // Eastern or Southern

    var r1 = map.rooms[i]; // TODO: ugh
    var r2 = map.rooms[j];

    // figure out a point in the walls between the rooms
    // TODO: randomization

    var r1_x: Pos.Dim = r1.getMaxX();
    var r1_y: Pos.Dim = r1.getMaxY();
    var r2_x: Pos.Dim = r2.getMinX();
    var r2_y: Pos.Dim = r2.getMinY();

    if (j == i + 1) { // Eastward dig
        r1_y = @divTrunc(r1.getMinY() + r1.getMaxY(), 2);
        r2_y = @divTrunc(r2.getMinY() + r2.getMaxY(), 2);
    } else { // Southward dig
        r1_x = @divTrunc(r1.getMinX() + r1.getMaxX(), 2);
        r2_x = @divTrunc(r2.getMinX() + r2.getMaxX(), 2);
    }
    std.debug.print("digging from {},{} to {},{}\n", .{ r1_x, r1_y, r2_x, r2_y });
    map.dig(Pos.init(r1_x, r1_y), Pos.init(r2_x, r2_y)) catch unreachable; // TODO incorrect
}

// ========================================================
//
// Mapgen interface: create a level using the traditional Rogue
// algorithms
//

pub fn createRogueLevel(config: LevelConfig) !*Map {
    const r = Randomizer{};
    var ingraph = [_]bool{false} ** max_rooms; // Rooms connected to graph
    var connections = [_]bool{false} ** (max_rooms * max_rooms);
    var map = try Map.init(config.allocator, config.xSize, config.ySize, rooms_dim, rooms_dim);
    errdefer map.deinit();

    // TODO: select gone rooms and deal with those

    for (0..max_rooms) |i| {
        const room = try makeRogueRoom(@intCast(i), map, r);

        // TODO: place gold
        // TODO: place monster
        try map.addRoom(room);
    }

    // Connect passages
    // TODO: list of rooms, shuffled

    var r1: usize = r.roll(max_rooms); // 0..8
    ingraph[r1] = true;
    var roomcount: usize = 1;
    var lower: usize = 0;

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
        if (r2 < 1000) { // Found adjacent room not already in graph
            ingraph[@intCast(r2)] = true;
            connectRooms(map, r1, r2); // TODO
            setConnected(&connections, @intCast(r1), @intCast(r2));
            roomcount += 1;
        } else {
            // No adjacent rooms outside of graph: start over with a new room
            // TODO must be in graph
            r1 = lower;
            lower += 1; // TODO: this is crap
        }
    } // While roomcount < max_rooms

    // TODO: Add passages randomly some number of times
    // If not connected

    // TODO: keep track of map.passages[] for some reason

    if (config.player) |p| {
        try map.setMonster(p, 8, 3); // TODO: random room and position
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
    const r = Randomizer{};
    var map = try Map.init(tallocator, 80, 24, 3, 3);
    defer map.deinit();

    // TODO this is of course very carefully crafted to pass
    const xroomsize = 26;
    const yroomsize = 8;
    const xsize = 14; // actual size 15
    const ysize = 5; // actual size 6
    const xoffset = 6;
    const yoffset = 1;

    for (0..rooms_dim) |y| {
        for (0..rooms_dim) |x| {
            const i: i16 = @intCast(y * rooms_dim + x);
            var room = try makeRogueRoom(i, map, r);

            try expect(room.getMinX() == x * xroomsize + xoffset);
            try expect(room.getMaxX() == x * xroomsize + xoffset + xsize);
            try expect(room.getMinY() == y * yroomsize + yoffset);
            try expect(room.getMaxY() == y * yroomsize + yoffset + ysize);
        }
    }
}

test "create Rogue level" {
    var map = try createRogueLevel(.{ .allocator = tallocator, .xSize = 80, .ySize = 24, .mapgen = .ROGUE });
    defer map.deinit();
}

// EOF
