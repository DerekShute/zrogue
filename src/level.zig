const std = @import("std");
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;
const MapContents = zrogue.MapContents;

// ===================
//
// Spot on the map
//
// DOT level_Place -> Thing [label="refers"]

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
// Map (global)
//
// DOT level_Map -> level_Place [label="contains"]
// DOT level_Map -> std_mem_Allocator [label="receives"]
//
pub const Map = struct {
    allocator: std.mem.Allocator,
    places: []Place,
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

    pub fn getChar(self: *Map, x: Pos.Dim, y: Pos.Dim) !MapContents {
        const place = try self.toPlace(x, y);
        return place.getChar();
    }

    pub fn passable(self: *Map, x: Pos.Dim, y: Pos.Dim) !bool {
        const place = try self.toPlace(x, y);
        return place.passable();
    }

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

    pub fn isLit(self: *Map, x: Pos.Dim, y: Pos.Dim) !bool {
        const place = try self.toPlace(x, y);
        return place.isLit();
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

    //
    // TODO: unless horiz and vert walls wanted, this is irrelevant
    //
    pub fn drawRoom(self: *Map, x: Pos.Dim, y: Pos.Dim, maxx: Pos.Dim, maxy: Pos.Dim) !void {
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

        // TODO sign check
        if (maxx >= self.width)
            return ZrogueError.MapOverFlow;
        if (maxy >= self.height)
            return ZrogueError.MapOverFlow;
        if (x >= maxx)
            return ZrogueError.MapOverFlow;
        if (y >= maxy)
            return ZrogueError.MapOverFlow;

        // Horizontal bars in the corners
        T.vert(self.places, self.width, x, .{ y + 1, maxy - 1 });
        T.vert(self.places, self.width, maxx, .{ y + 1, maxy - 1 });
        T.horiz(self.places, self.width, y, .{ x, maxx });
        T.horiz(self.places, self.width, maxy, .{ x, maxx });

        // Floor
        T.field(self.places, self.width, .{ x + 1, y + 1 }, .{ maxx - 1, maxy - 1 });
    }
};

//
// Unit Tests
//

test "map smoke test" {
    var map: Map = try Map.config(std.testing.allocator, 100, 100);
    defer map.deinit();

    try map.drawRoom(10, 10, 20, 20);

    try std.testing.expect(try map.isLit(15, 15) == false);
    try std.testing.expect(try map.isKnown(15, 15) == false);
    try std.testing.expect(try map.getChar(0, 0) == MapContents.unknown);
    try std.testing.expect(try map.getChar(10, 10) == MapContents.wall);

    try map.setKnown(15, 15, true);
    try std.testing.expect(try map.isKnown(15, 15) == true);
    try map.setKnown(15, 15, false);
    try std.testing.expect(try map.isKnown(15, 15) == false);

    try map.setRegionKnown(12, 12, 15, 15);
    try std.testing.expect(try map.isKnown(12, 12) == true);
    try std.testing.expect(try map.isKnown(15, 15) == true);
    try std.testing.expect(try map.isKnown(16, 16) == false);
    try std.testing.expect(try map.isKnown(11, 11) == false);
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
    try std.testing.expect(thing == null); // Nothing there
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

    try std.testing.expectError(ZrogueError.MapOverFlow, map.drawRoom(15, 15, 4, 18));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.drawRoom(15, 15, 18, 4));
}

test "draw an oversize room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20);
    defer map.deinit();

    try std.testing.expectError(ZrogueError.MapOverFlow, map.drawRoom(0, 0, 0, 100));
    try std.testing.expectError(ZrogueError.MapOverFlow, map.drawRoom(0, 0, 100, 0));
}

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
