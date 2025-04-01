const std = @import("std");
const mapgen = @import("mapgen.zig");

const Item = @import("../item.zig").Item;
const Map = @import("../map.zig").Map;
const MapTile = @import("../zrogue.zig").MapTile;
const Pos = @import("../zrogue.zig").Pos;
const Room = @import("../map.zig").Room;

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
    var room = try Room.config(tl, br); // REFACTOR interface as (tl, size-as-pos)?
    if (r.intRangeAtMost(usize, 1, 10) < map.level) {
        room.setDark();
        // TODO: maze (1 in 15)
    }

    return room;
}

// TODO: into Map?  It assumes a room grid
fn isRoomAdjacent(i: usize, j: usize) bool {
    const i_row = @divTrunc(i, rooms_dim);
    const j_row = @divTrunc(j, rooms_dim);
    const i_col = @mod(i, rooms_dim);
    const j_col = @mod(j, rooms_dim);

    if (i_row == j_row) { // neighbors, same row
        return if ((i == j + 1) or (j == i + 1)) true else false;
    } else if (i_col == j_col) { // neighbors, same column
        return if ((i_row == j_row + 1) or (j_row == i_row + 1)) true else false;
    }
    return false;
}

fn findFloor(r: *std.Random, room: *Room) Pos {
    // TODO: want a spot without anything else
    const row = r.intRangeAtMost(Pos.Dim, room.getMinX() + 1, room.getMaxX() - 1);
    const col = r.intRangeAtMost(Pos.Dim, room.getMinY() + 1, room.getMaxY() - 1);
    return Pos.init(row, col);
}

// Connection graph between rooms

fn setConnected(graph: []bool, r1: usize, r2: usize) void {
    graph[r1 * max_rooms + r2] = true;
    graph[r2 * max_rooms + r1] = true;
}

fn notConnected(graph: []bool, r1: usize, r2: usize) bool {
    return !graph[r1 * max_rooms + r2];
}

// Dig a passage

fn connectRooms(map: *Map, rn1: usize, rn2: usize, r: *std.Random) !void {
    const i = @min(rn1, rn2); // Western or Northern
    const j = @max(rn1, rn2); // Eastern or Southern
    var r1 = mapgen.getRoom(map, i);
    var r2 = mapgen.getRoom(map, j);

    // Pick valid connection points (along the opposite room sides, not on
    // the corners, and a location for the midpoint)

    // TODO: secret passages, which mark each spot (for map reveal?)

    if (j == i + 1) { // Eastward dig
        const start_x = r1.getMaxX();
        const r1_y = r.intRangeAtMost(Pos.Dim, r1.getMinY() + 1, r1.getMaxY() - 1);
        const end_x = r2.getMinX();
        const r2_y = r.intRangeAtMost(Pos.Dim, r2.getMinY() + 1, r2.getMaxY() - 1);
        const mid_x = r.intRangeAtMost(Pos.Dim, start_x + 1, end_x - 1);
        std.debug.print("Connecting {}-{} at {},{}-{},{} mid {}\n", .{ rn1, rn2, start_x, r1_y, end_x, r2_y, mid_x });
        try mapgen.addEastCorridor(map, Pos.init(start_x, r1_y), Pos.init(end_x, r2_y), mid_x);
    } else { // Southward dig
        const r1_x = r.intRangeAtMost(Pos.Dim, r1.getMinX() + 1, r1.getMaxX() - 1);
        const start_y = r1.getMaxY();
        const r2_x = r.intRangeAtMost(Pos.Dim, r2.getMinX() + 1, r2.getMaxX() - 1);
        const end_y = r2.getMinY();
        const mid_y = r.intRangeAtMost(Pos.Dim, start_y + 1, end_y - 1);
        std.debug.print("Connecting {}-{} at {},{}-{},{} mid {}\n", .{ rn1, rn2, r1_x, start_y, r2_x, end_y, mid_y });
        try mapgen.addSouthCorridor(map, Pos.init(r1_x, start_y), Pos.init(r2_x, end_y), mid_y);
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
    map.level = config.level;

    // TODO: count gone rooms, set as such, remove from slice

    for (0..max_rooms) |i| {
        var room = try makeRogueRoom(@intCast(i), map, config.rand);
        try mapgen.addRoom(map, room);

        // Place gold

        // TODO: if !amulet and if level < max_level
        if (config.rand.intRangeAtMost(usize, 0, 1) == 0) { // 50%
            const pos = findFloor(config.rand, &room);
            // REFACTOR: addItem takes Pos instead?
            // TODO: gold quantity
            try map.addItem(Item.config(pos.getX(), pos.getY(), .gold));
        }

        // TODO: place monster
    }

    // Connect passages.  Start with first room in slice

    var r1: usize = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
    ingraph[r1] = true;
    var roomcount: usize = 1;

    // Find an adjacent room to connect with

    while (roomcount < max_rooms) {
        var j: usize = 0;
        var r2: usize = 1000;
        for (0..max_rooms) |i| {
            if (isRoomAdjacent(r1, i) and !ingraph[i]) {
                j += 1;
                if (config.rand.intRangeAtMost(usize, 0, j) == 0) {
                    r2 = @intCast(i);
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

    // Add passages to the graph for loop variety

    roomcount = config.rand.intRangeAtMost(usize, 0, 4);
    while (roomcount > 0) {
        r1 = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);

        // Find an adjacent room not already connected

        var j: usize = 0;
        var r2: usize = 1000;
        for (0..max_rooms) |i| {
            if (isRoomAdjacent(r1, i) and notConnected(&connections, r1, i)) {
                j += 1;
                if (config.rand.intRangeAtMost(usize, 0, j) == 0) {
                    r2 = @intCast(i);
                }
            }
        }
        if (r2 < 1000) {
            try connectRooms(map, r1, r2, config.rand);
            setConnected(&connections, @intCast(r1), @intCast(r2));
        }

        roomcount -= 1;
    }

    // If not connected

    // TODO: keep track of map.passages[] for serialization

    // Place the stairs
    {
        // TODO: if level < X, else stairs up
        // REFACTOR: 'position of some room floor' is boilerplate
        const i = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
        const room = mapgen.getRoom(map, i);
        const pos = findFloor(config.rand, room);
        // REFACTOR: setTile takes Pos instead?
        try map.setTile(pos.getX(), pos.getY(), .stairs_down);
    }

    if (config.player) |p| {
        const i = config.rand.intRangeAtMost(usize, 0, max_rooms - 1);
        const room = mapgen.getRoom(map, i);
        const pos = findFloor(config.rand, room);
        // REFACTOR: setMonster takes Pos instead?
        try map.setMonster(p, pos.getX(), pos.getY());
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

fn testsTrue(i: usize, j: usize) !void {
    try expect(isRoomAdjacent(i, j) == true);
    try expect(isRoomAdjacent(j, i) == true);
}

fn testsFalse(i: usize, j: usize) !void {
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
        .level = 2,
        .mapgen = .ROGUE,
    };

    var map = try createRogueLevel(config);
    defer map.deinit();

    try expect(map.level == 2);

    // TODO: mock Player and validate positioning
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
