const std = @import("std");
const Thing = @import("thing.zig").Thing;

// ===================
// Spot on the map

const Place = struct {
    ch: u8 = ' ', // TODO manifest constant
    flags: u8 = 0, // TODO room flags as packed struct(u8)
    monst: ?*Thing = null,

    pub fn getChar(self: *Place) u8 {
        if (self.monst) |monst| {
            return monst.getChar();
        }
        return self.ch;
    }

    pub fn setChar(self: *Place, tochar: u8) void {
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

    // TODO: getFlags(), setFlags()
};

pub const Map = struct {
    allocator: std.mem.Allocator,
    places: []Place,
    height: u16,
    width: u16,

    //
    // Allocate and initialize
    //
    pub fn init(allocator: std.mem.Allocator, height: u16, width: u16) !*Map {
        const map: *Map = try allocator.create(Map);
        errdefer Map.deinit(map); // This should handle all failure-cleanup
        map.* = .{
            .allocator = allocator,
            .height = height,
            .width = width,
            .places = &.{}, // Empty slice
        };
        // TODO this blows up u8 height width
        map.places = try allocator.alloc(Place, height * width);
        for (map.places) |*place| {
            place.setChar(' '); // TODO constants
            place.flags = 0;
            place.monst = null;
        }

        return map;
    }

    // Teardown

    pub fn deinit(self: *Map) void {
        const allocator = self.allocator;
        if (self.places.len != 0) {
            allocator.free(self.places);
        }
        allocator.destroy(self);
    }

    // Utility

    fn toPlace(self: *Map, xy: [2]u16) !*Place {
        if (xy[0] >= self.width)
            return error.OverFlow;
        if (xy[1] >= self.height)
            return error.OverFlow;

        const loc = xy[0] + xy[1] * self.width;
        return &self.places[loc];
    }

    // Methods

    pub fn getChar(self: *Map, xy: [2]u16) !u8 {
        const place = try self.toPlace(xy);
        return place.getChar();
    }

    pub fn getMonster(self: *Map, xy: [2]u16) !?*Thing {
        const place = try self.toPlace(xy);
        return place.getMonst();
    }

    pub fn setMonster(self: *Map, monst: *Thing, xy: [2]u16) !void {
        const place = try self.toPlace(xy);
        try place.setMonst(monst);
        monst.setPos(xy); // TODO is this the best way?
    }

    pub fn drawRoom(self: *Map, xy: [2]u16, max: [2]u16) !void {
        const T = struct {
            // End x or y is inclusive
            fn vert(places: []Place, width: u16, startx: u16, y: [2]u16) void {
                for (y[0]..y[1] + 1) |at| {
                    const loc = startx + at * width;
                    places[loc].setChar('|'); // TODO: manifest constant
                }
            }

            fn horiz(places: []Place, width: u16, starty: u16, x: [2]u16) void {
                for (x[0]..x[1] + 1) |at| {
                    const loc = at + starty * width;
                    places[loc].setChar('-'); // TODO: manifest constant
                }
            }

            fn field(places: []Place, width: u16, start: [2]u16, limit: [2]u16) void {
                for (start[1]..limit[1] + 1) |c_y| {
                    for (start[0]..limit[0] + 1) |c_x| {
                        const loc = c_x + c_y * width;
                        places[loc].setChar('.'); // TODO: manifest constant
                    }
                }
            }
        };

        if (max[0] >= self.width)
            return error.OverFlow;
        if (max[1] >= self.height)
            return error.OverFlow;
        if (xy[0] >= max[0])
            return error.OverFlow;
        if (xy[1] >= max[1])
            return error.OverFlow;

        // Horizontal bars in the corners
        T.vert(self.places, self.width, xy[0], .{ xy[1] + 1, max[1] - 1 });
        T.vert(self.places, self.width, max[0], .{ xy[1] + 1, max[1] - 1 });
        T.horiz(self.places, self.width, xy[1], .{ xy[0], max[0] });
        T.horiz(self.places, self.width, max[1], .{ xy[0], max[0] });

        // Floor
        T.field(self.places, self.width, .{ xy[0] + 1, xy[1] + 1 }, .{ max[0] - 1, max[1] - 1 });
    }
};

//
// Plethora of tests
//

test "allocate and free" {
    const map: *Map = try Map.init(std.testing.allocator, 100, 100);
    defer map.deinit();
}

test "fails to allocate any of map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, Map.init(failing.allocator(), 10, 10));
}

test "fails to allocate all of map" { // right now there is two allocations
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try std.testing.expectError(error.OutOfMemory, Map.init(failing.allocator(), 10, 10));
}

test "allocate and free zero size" {
    // Not sure what the allocator does for 'allocate zero' but here you are

    const map: *Map = try Map.init(std.testing.allocator, 0, 0);
    defer map.deinit();
}

test "ask about valid map location" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer map.deinit();

    const thing = try map.getMonster(.{ 4, 4 });
    try std.testing.expect(thing == null); // Nothing there
}

test "ask about thing at invalid map location" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer map.deinit();
    try std.testing.expectError(error.OverFlow, map.getMonster(.{ 0, 20 }));
    try std.testing.expectError(error.OverFlow, map.getMonster(.{ 20, 0 }));
}

test "ask about a character on the map" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer map.deinit();
    try std.testing.expect(try map.getChar(.{ 0, 0 }) == ' ');
}

test "ask about invalid character on the map" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer map.deinit();
    try std.testing.expectError(error.OverFlow, map.getChar(.{ 20, 0 }));
    try std.testing.expectError(error.OverFlow, map.getChar(.{ 0, 20 }));
}

test "draw an invalid room" {
    const map: *Map = try Map.init(std.testing.allocator, 20, 20);
    defer map.deinit();

    try std.testing.expectError(error.OverFlow, map.drawRoom(.{ 15, 15 }, .{ 4, 18 }));
    try std.testing.expectError(error.OverFlow, map.drawRoom(.{ 15, 15 }, .{ 18, 4 }));
}

test "draw an oversize room" {
    const map: *Map = try Map.init(std.testing.allocator, 20, 20);
    defer map.deinit();

    try std.testing.expectError(error.OverFlow, map.drawRoom(.{ 0, 0 }, .{ 0, 100 }));
    try std.testing.expectError(error.OverFlow, map.drawRoom(.{ 0, 0 }, .{ 100, 0 }));
}

test "draw a valid room and test corners" {
    const map: *Map = try Map.init(std.testing.allocator, 50, 50);
    defer map.deinit();

    try map.drawRoom(.{ 10, 10 }, .{ 20, 20 });
    // Corners are '-'
    try std.testing.expect(try map.getChar(.{ 10, 10 }) == '-');
    try std.testing.expect(try map.getChar(.{ 20, 10 }) == '-');
    try std.testing.expect(try map.getChar(.{ 10, 20 }) == '-');
    try std.testing.expect(try map.getChar(.{ 20, 20 }) == '-');
    try std.testing.expect(try map.getChar(.{ 19, 19 }) == '.');
    try std.testing.expect(try map.getChar(.{ 11, 11 }) == '.');
    try std.testing.expect(try map.getChar(.{ 11, 19 }) == '.');
    try std.testing.expect(try map.getChar(.{ 19, 11 }) == '.');
}

test "putting monsters places" {
    const map: *Map = try Map.init(std.testing.allocator, 50, 50);
    defer Map.deinit(map);
    var thing = Thing{ .xy = .{ 0, 0 }, .ch = '@' };
    var thing2 = Thing{ .xy = .{ 0, 0 }, .ch = '@' };

    try map.setMonster(&thing, .{ 10, 10 });
    try std.testing.expect(thing.atPos(.{ 10, 10 }));

    try std.testing.expectError(error.AlreadyOccupied, map.setMonster(&thing2, .{ 10, 10 }));
}

// EOF
