const std = @import("std");
const expect = std.testing.expect;
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;
const MapContents = zrogue.MapContents;

// ===================
//
// Spot on the map
//
// DOT map_Place -> Thing [label="refers"]

const Place = struct {
    ch: MapContents = MapContents.unknown,
    flags: packed struct {
        lit: bool,
        known: bool,
    },
    monst: ?*Thing,

    // Constructor, probably not idiomatic

    pub fn config(self: *Place) void {
        self.ch = MapContents.unknown;
        self.flags = .{ .lit = false, .known = false };
        self.monst = null;
    }

    // Methods

    pub fn getChar(self: *Place) MapContents {
        if (self.monst) |monst| {
            return monst.getChar();
        }
        return self.ch;
    }

    pub fn passable(self: *Place) bool {
        return self.ch.passable();
    }

    pub fn setChar(self: *Place, tochar: MapContents) void {
        self.ch = tochar;
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

    pub fn isLit(self: *Place) bool {
        return self.flags.lit;
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

    pub fn getChar(self: *Map, x: Pos.Dim, y: Pos.Dim) !MapContents {
        const place = try self.toPlace(x, y);
        return place.getChar();
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
        const T = struct {
            // End x or y is inclusive
            fn vert(places: []Place, width: Pos.Dim, startx: Pos.Dim, yrange: [2]Pos.Dim) void {
                const _starty: usize = @intCast(yrange[0]);
                const _endy: usize = @intCast(yrange[1]);
                const _width: usize = @intCast(width);
                const _startx: usize = @intCast(startx);
                for (_starty.._endy + 1) |at| {
                    places[_startx + at * _width].setChar(MapContents.wall);
                }
            }

            fn horiz(places: []Place, width: Pos.Dim, starty: Pos.Dim, xrange: [2]Pos.Dim) void {
                const _starty: usize = @intCast(starty);
                const _startx: usize = @intCast(xrange[0]);
                const _endx: usize = @intCast(xrange[1]);
                const _width: usize = @intCast(width);
                for (_startx.._endx + 1) |at| {
                    places[at + _starty * _width].setChar(MapContents.wall);
                }
            }

            fn field(places: []Place, width: Pos.Dim, start: [2]Pos.Dim, limit: [2]Pos.Dim) void {
                const _starty: usize = @intCast(start[1]);
                const _endy: usize = @intCast(limit[1]);
                const _startx: usize = @intCast(start[0]);
                const _endx: usize = @intCast(limit[0]);
                const _width: usize = @intCast(width);
                for (_starty.._endy + 1) |c_y| {
                    for (_startx.._endx + 1) |c_x| {
                        places[c_x + c_y * _width].setChar(MapContents.floor);
                    }
                }
            }
        };

        if ((r.getMaxX() > self.width) or (r.getMaxY() > self.height)) {
            return ZrogueError.MapOverFlow;
        }

        // TODO 'removed' room of 1x1 size is allowed
        if ((r.getMaxX() < r.getMinX()) or (r.getMaxY() < r.getMinY())) {
            return ZrogueError.OutOfBounds;
        }

        // TODO array of, and you know which index based on room's position
        self.room = r;

        // Horizontal bars in the corners
        T.vert(self.places, self.width, r.getMinX(), .{ r.getMinY() + 1, r.getMaxY() - 1 });
        T.vert(self.places, self.width, r.getMaxX(), .{ r.getMinY() + 1, r.getMaxY() - 1 });
        T.horiz(self.places, self.width, r.getMinY(), .{ r.getMinX(), r.getMaxX() });
        T.horiz(self.places, self.width, r.getMaxY(), .{ r.getMinX(), r.getMaxX() });

        // Floor
        T.field(self.places, self.width, .{ r.getMinX() + 1, r.getMinY() + 1 }, .{ r.getMaxX() - 1, r.getMaxY() - 1 });
    }

    pub fn isLit(self: *Map, p: Pos) bool {
        if (self.room.isInside(p)) {
            return self.room.isLit();
        }
        return false;
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

// Rooms

test "add a room and ask about it" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    const r1 = Room.config(Pos.init(5, 5), Pos.init(10, 10));
    try map.addRoom(r1);
    try expect(map.inRoom(Pos.init(7, 7)) == true);
    try expect(map.inRoom(Pos.init(19, 19)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
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
    try expect(try map.getChar(0, 0) == MapContents.unknown);
    try expect(try map.getChar(10, 10) == MapContents.wall);

    try map.setKnown(15, 15, true);
    try expect(try map.isKnown(15, 15) == true);
    try map.setKnown(15, 15, false);
    try expect(try map.isKnown(15, 15) == false);

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
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getChar(20, 0));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.getChar(0, 20));
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
    var thing = Thing{ .xy = Pos.init(0, 0), .ch = MapContents.player };
    var thing2 = Thing{ .xy = Pos.init(0, 0), .ch = MapContents.player };

    var m: *Map = &map;
    try m.setMonster(&thing, 10, 10);
    try std.testing.expect(thing.atXY(10, 10));

    try std.testing.expectError(error.AlreadyOccupied, map.setMonster(&thing2, 10, 10));
}

// EOF
