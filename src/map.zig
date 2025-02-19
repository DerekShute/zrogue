const std = @import("std");
const expect = std.testing.expect;
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;
const MapTile = zrogue.MapTile;

// ===================
//
// Spot on the map
//
// DOT map_Place -> Thing [label="refers"]
// Dot map_Place -> MapTile [label="contains"]

const Place = struct {
    tile: MapTile = MapTile.unknown,
    flags: packed struct {
        known: bool,
    },
    monst: ?*Thing,

    // Constructor, probably not idiomatic

    pub fn config(self: *Place) void {
        self.tile = MapTile.unknown;
        self.flags = .{ .known = false };
        self.monst = null;
    }

    // Methods

    pub fn getTile(self: *Place) MapTile {
        if (self.monst) |monst| {
            return monst.getTile();
        }
        return self.tile;
    }

    pub fn passable(self: *Place) bool {
        return self.tile.passable();
    }

    pub fn setTile(self: *Place, to: MapTile) void {
        self.tile = to;
    }

    pub fn getMonst(self: *Place) ?*Thing {
        return self.monst;
    }

    pub fn setMonst(self: *Place, new_monst: *Thing) !void {
        if (self.monst) |_| {
            return error.AlreadyOccupied; // TODO collect errors
        }
        self.monst = new_monst;
    }

    pub fn removeMonst(self: *Place) !void {
        if (self.monst) |_| {
            self.monst = null;
        }
    }

    pub fn isKnown(self: *Place) bool {
        return self.flags.known;
    }

    pub fn setKnown(self: *Place, val: bool) void {
        self.flags.known = val;
    }
};

// ===================
//
// Room
//

pub const Room = struct {
    topleft: Pos,
    bottomright: Pos,
    flags: packed struct {
        lit: bool,
    },

    // Constructor

    pub fn config(tl: Pos, br: Pos) Room {
        return .{
            .topleft = tl,
            .bottomright = br,
            .flags = .{
                .lit = true,
            },
        };
    }

    // Methods

    pub fn getMinX(self: *Room) Pos.Dim {
        return self.topleft.getX();
    }

    pub fn getMaxX(self: *Room) Pos.Dim {
        return self.bottomright.getX();
    }

    pub fn getMinY(self: *Room) Pos.Dim {
        return self.topleft.getY();
    }

    pub fn getMaxY(self: *Room) Pos.Dim {
        return self.bottomright.getY();
    }

    pub fn isLit(self: *Room) bool {
        return self.flags.lit;
    }

    pub fn setDark(self: *Room) void {
        self.flags.lit = false;
    }

    pub fn isInside(self: *Room, p: Pos) bool {
        if ((p.getX() < self.topleft.getX()) or (p.getX() > self.bottomright.getX()) or (p.getY() < self.topleft.getY()) or (p.getY() > self.bottomright.getY())) {
            return false;
        }
        return true;
    }

    //
    // TODO: can vtable this to have different types of room
    pub fn draw(self: *Room, map: *Map) ZrogueError!void {
        const Fns = struct {
            fn vert(m: *Map, startx: Pos.Dim, yrange: [2]Pos.Dim) !void {
                for (@intCast(yrange[0])..@intCast(yrange[1] + 1)) |y| {
                    try m.setTile(startx, @intCast(y), MapTile.wall);
                }
            }

            fn horiz(m: *Map, starty: Pos.Dim, xrange: [2]Pos.Dim) !void {
                for (@intCast(xrange[0])..@intCast(xrange[1] + 1)) |x| {
                    try m.setTile(@intCast(x), starty, MapTile.wall);
                }
            }

            fn field(m: *Map, start: Pos, limit: Pos) !void {
                const _startx: usize = @intCast(start.getX());
                const _starty: usize = @intCast(start.getY());
                const _endx: usize = @intCast(limit.getX());
                const _endy: usize = @intCast(limit.getY());
                for (_starty.._endy + 1) |y| {
                    for (_startx.._endx + 1) |x| {
                        try m.setTile(@intCast(x), @intCast(y), MapTile.floor);
                    }
                }
            }
        };

        const minx = self.getMinX();
        const miny = self.getMinY();
        const maxx = self.getMaxX();
        const maxy = self.getMaxY();

        // Horizontal bars in the corners
        try Fns.vert(map, minx, .{ miny + 1, maxy - 1 });
        try Fns.vert(map, maxx, .{ miny + 1, maxy - 1 });
        try Fns.horiz(map, miny, .{ minx, maxx });
        try Fns.horiz(map, maxy, .{ minx, maxx });

        // Floor
        try Fns.field(map, Pos.init(minx + 1, miny + 1), Pos.init(maxx - 1, maxy - 1));
    } // draw

    // TODO: Vtable for different shaped rooms
    pub fn reveal(self: *Room, map: *Map) !void {
        const minx = self.getMinX();
        const miny = self.getMinY();
        const maxx = self.getMaxX();
        const maxy = self.getMaxY();
        // TODO do only once via self.flags.known
        if (self.isLit()) {
            try map.setRegionKnown(minx, miny, maxx, maxy);
        }
    }
};

// ===================
//
// Map (global)
//
// DOT Map -> map_Place [label="contains"]
// DOT Map -> map_Room [label="contains"]
// DOT Map -> std_mem_Allocator [label="receives"]
//
pub const Map = struct {
    allocator: std.mem.Allocator,
    places: []Place,
    room: Room, // TODO array of them
    height: Pos.Dim,
    width: Pos.Dim,

    // Allocate and teardown

    pub fn config(allocator: std.mem.Allocator, height: Pos.Dim, width: Pos.Dim) !Map {
        const places = try allocator.alloc(Place, @intCast(height * width));
        errdefer allocator.free(places);
        for (places) |*place| {
            place.config();
        }

        return .{
            .allocator = allocator,
            .height = height,
            .width = width,
            .places = places,
            .room = undefined,
        };
    }

    pub fn deinit(self: *Map) void {
        const allocator = self.allocator;
        if (self.places.len != 0) {
            allocator.free(self.places);
        }
    }

    // Utility

    fn toPlace(self: *Map, x: Pos.Dim, y: Pos.Dim) ZrogueError!*Place {
        // TODO: sign check
        if (x >= self.width)
            return ZrogueError.MapOverFlow;
        if (y >= self.height)
            return ZrogueError.MapOverFlow;

        const loc: usize = @intCast(x + y * self.width);
        return &self.places[loc];
    }

    // Methods

    pub fn getHeight(self: *Map) Pos.Dim {
        return self.height;
    }

    pub fn getWidth(self: *Map) Pos.Dim {
        return self.width;
    }

    pub fn getTile(self: *Map, x: Pos.Dim, y: Pos.Dim) !MapTile {
        const place = try self.toPlace(x, y);
        return place.getTile();
    }

    pub fn setTile(self: *Map, x: Pos.Dim, y: Pos.Dim, tile: MapTile) !void {
        const place = try self.toPlace(x, y);
        place.setTile(tile);
    }

    pub fn passable(self: *Map, x: Pos.Dim, y: Pos.Dim) !bool {
        const place = try self.toPlace(x, y);
        return place.passable();
    }

    // monsters

    pub fn getMonster(self: *Map, x: Pos.Dim, y: Pos.Dim) !?*Thing {
        const place = try self.toPlace(x, y);
        return place.getMonst();
    }

    pub fn setMonster(self: *Map, monst: *Thing, x: Pos.Dim, y: Pos.Dim) !void {
        const place = try self.toPlace(x, y);
        try place.setMonst(monst);
        monst.setXY(x, y);
    }

    pub fn removeMonster(self: *Map, x: Pos.Dim, y: Pos.Dim) !void {
        const place = try self.toPlace(x, y);
        const monst = place.getMonst();
        if (monst) |m| {
            try place.removeMonst();
            m.setXY(-1, -1);
        }
    }

    pub fn isKnown(self: *Map, x: Pos.Dim, y: Pos.Dim) !bool {
        const place = try self.toPlace(x, y);
        return place.isKnown();
    }

    pub fn setKnown(self: *Map, x: Pos.Dim, y: Pos.Dim, val: bool) !void {
        const place = try self.toPlace(x, y);
        place.setKnown(val);
    }

    pub fn setRegionKnown(self: *Map, x: Pos.Dim, y: Pos.Dim, maxx: Pos.Dim, maxy: Pos.Dim) !void {
        const _minx: usize = @intCast(x);
        const _miny: usize = @intCast(y);
        const _maxx: usize = @intCast(maxx + 1);
        const _maxy: usize = @intCast(maxy + 1);
        for (_miny.._maxy) |_y| {
            for (_minx.._maxx) |_x| {
                const place = try self.toPlace(@intCast(_x), @intCast(_y));
                place.setKnown(true);
            }
        }
    }

    // rooms

    pub fn inRoom(self: *Map, p: Pos) bool {
        return self.room.isInside(p);
    }

    pub fn addRoom(self: *Map, room: Room) ZrogueError!void {
        var r = room; // force to var reference

        if ((r.getMaxX() > self.width) or (r.getMaxY() > self.height)) {
            return ZrogueError.MapOverFlow;
        }

        // TODO 'removed' room of 1x1 size is allowed
        if ((r.getMaxX() < r.getMinX()) or (r.getMaxY() < r.getMinY())) {
            return ZrogueError.OutOfBounds;
        }

        // TODO test for room alignment to room grid

        // TODO array of, and you know which index based on room's position
        self.room = r;
        try r.draw(self);
    }

    pub fn isLit(self: *Map, p: Pos) bool {
        if (self.room.isInside(p)) {
            return self.room.isLit();
        }
        return false;
    }

    pub fn revealRoom(self: *Map, p: Pos) !void {
        if (self.inRoom(p)) {
            var r = self.room; // TODO one of many rooms
            try r.reveal(self);
        }
    }
};

//
// Unit Tests
//

// Rooms

test "create a room and test properties" {
    var room: Room = Room.config(Pos.init(10, 10), Pos.init(20, 20));

    try expect(room.getMaxX() == 20);
    try expect(room.getMaxY() == 20);
    try expect(room.getMinX() == 10);
    try expect(room.getMinY() == 10);
    try expect(room.isInside(Pos.init(15, 15)));
    try expect(room.isInside(Pos.init(10, 10)));
    try expect(room.isInside(Pos.init(20, 20)));
    try expect(room.isInside(Pos.init(10, 20)));
    try expect(room.isInside(Pos.init(20, 10)));
    try expect(!room.isInside(Pos.init(0, 0)));
    try expect(!room.isInside(Pos.init(-10, -10)));
    try expect(!room.isInside(Pos.init(10, 0)));
    try expect(!room.isInside(Pos.init(0, 10)));
    try expect(!room.isInside(Pos.init(15, 21)));

    try expect(room.isLit() == true);
    room.setDark();
    try expect(room.isLit() == false);
}

test "add a room and ask about it" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    const r1 = Room.config(Pos.init(5, 5), Pos.init(10, 10));
    try map.addRoom(r1);
    try expect(map.inRoom(Pos.init(7, 7)) == true);
    try expect(map.inRoom(Pos.init(19, 19)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
}

test "reveal room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    const r1 = Room.config(Pos.init(5, 5), Pos.init(10, 10));
    try map.addRoom(r1);
    try expect(try map.isKnown(7, 7) == false);
    try expect(try map.isKnown(4, 4) == false);
    try expect(try map.isKnown(11, 11) == false);
    try map.revealRoom(Pos.init(7, 7));
    try expect(try map.isKnown(5, 5) == true);
    try expect(try map.isKnown(10, 10) == true);
    try expect(try map.isKnown(4, 4) == false);
    try expect(try map.isKnown(11, 11) == false);
}

// Map

test "map smoke test" {
    var map: Map = try Map.config(std.testing.allocator, 100, 50);
    defer map.deinit();

    try map.addRoom(Room.config(Pos.init(10, 10), Pos.init(20, 20)));

    try std.testing.expect(map.getHeight() == 100);
    try std.testing.expect(map.getWidth() == 50);

    try expect(map.isLit(Pos.init(15, 15)) == true);
    // TODO set room dark, then ask again

    try expect(try map.isKnown(15, 15) == false);
    try expect(try map.getTile(0, 0) == MapTile.unknown);
    try expect(try map.getTile(10, 10) == MapTile.wall);

    try map.setKnown(15, 15, true);
    try expect(try map.isKnown(15, 15) == true);
    try map.setKnown(15, 15, false);
    try expect(try map.isKnown(15, 15) == false);

    // Explicit set tile inside a known room
    try map.setTile(17, 17, MapTile.wall);
    try expect(try map.getTile(17, 17) == MapTile.wall);

    try map.setRegionKnown(12, 12, 15, 15);
    try expect(try map.isKnown(12, 12) == true);
    try expect(try map.isKnown(15, 15) == true);
    try expect(try map.isKnown(16, 16) == false);
    try expect(try map.isKnown(11, 11) == false);
}

test "fails to allocate any of map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, Map.config(failing.allocator(), 10, 10));
}

test "allocate and free zero size" {
    // Not sure what the allocator does for 'allocate zero' but here you are

    var map: Map = try Map.config(std.testing.allocator, 0, 0);
    defer map.deinit();
}

test "ask about valid map location" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10);
    defer map.deinit();

    const thing = try map.getMonster(4, 4);
    try expect(thing == null); // Nothing there
}

test "ask about thing at invalid map location" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10);
    defer map.deinit();
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getMonster(0, 20));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getMonster(20, 0));
}

test "ask about invalid character on the map" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10);
    defer map.deinit();
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getTile(20, 0));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getTile(0, 20));
}

test "draw an invalid room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    const r1 = Room.config(Pos.init(15, 15), Pos.init(4, 18));
    try std.testing.expectError(ZrogueError.OutOfBounds, map.addRoom(r1));
    const r2 = Room.config(Pos.init(15, 15), Pos.init(18, 4));
    try std.testing.expectError(ZrogueError.OutOfBounds, map.addRoom(r2));
}

test "draw an oversize room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    const r1 = Room.config(Pos.init(0, 0), Pos.init(0, 100));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.addRoom(r1));
    const r2 = Room.config(Pos.init(0, 0), Pos.init(100, 0));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.addRoom(r2));
}

// Monsters

test "putting monsters places" {
    var map: Map = try Map.config(std.testing.allocator, 50, 50);
    defer map.deinit();
    var thing = Thing{ .xy = Pos.init(0, 0), .tile = MapTile.player };
    var thing2 = Thing{ .xy = Pos.init(0, 0), .tile = MapTile.player };

    var m: *Map = &map;
    try m.setMonster(&thing, 10, 10);
    try std.testing.expect(thing.atXY(10, 10));

    try std.testing.expectError(error.AlreadyOccupied, map.setMonster(&thing2, 10, 10));
}

// EOF
