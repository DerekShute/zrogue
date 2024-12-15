const std = @import("std");

// ===================
// Structure for monsters and objects

const Thing = struct {
    x: u8,
};

// ===================
// Spot on the map

const Place = struct {
    ch: u8,
    flags: u8, // TODO room flags as packed sruct(u8)
    monst: Thing, // TODO is a list, can be empty
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
            place.ch = ' '; // TODO constants
            place.flags = 0;
            place.monst.x = 0;
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

    pub fn charAt(self: *Map, xy: [2]u16) !u8 {
        if (xy[0] >= self.width)
            return error.OverFlow;
        if (xy[1] >= self.height)
            return error.OverFlow;

        const loc = xy[0] + xy[1] * self.width;
        return self.places[loc].ch;
    }

    pub fn monsterAt(self: *Map, xy: [2]u16) !?*Thing {
        if (xy[0] >= self.width)
            return error.OverFlow;
        if (xy[1] >= self.height)
            return error.OverFlow;

        const loc = xy[0] + xy[1] * self.width;
        return &self.places[loc].monst; // TODO could be nothing there
    }

    pub fn drawRoom(self: *Map, xy: [2]u16, max: [2]u16) !void {
        const T = struct {
            // End x or y is inclusive
            fn vert(places: []Place, width: u16, startx: u16, y: [2]u16) void {
                for (y[0]..y[1] + 1) |at| {
                    const loc = startx + at * width;
                    places[loc].ch = '|'; // TODO access function
                }
            }

            fn horiz(places: []Place, width: u16, starty: u16, x: [2]u16) void {
                for (x[0]..x[1] + 1) |at| {
                    const loc = at + starty * width;
                    places[loc].ch = '-'; // TODO access function
                }
            }

            fn field(places: []Place, width: u16, start: [2]u16, limit: [2]u16) void {
                for (start[1]..limit[1] + 1) |c_y| {
                    for (start[0]..limit[0] + 1) |c_x| {
                        const loc = c_x + c_y * width;
                        places[loc].ch = '.';
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
    defer Map.deinit(map);
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
    defer Map.deinit(map);
}

test "ask about valid map location" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer Map.deinit(map);

    const thing = try Map.monsterAt(map, .{ 4, 4 });
    try std.testing.expect(thing != null); // TODO only if something there
}

test "ask about thing at invalid map location" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer Map.deinit(map);
    try std.testing.expectError(error.OverFlow, Map.monsterAt(map, .{ 0, 20 }));
    try std.testing.expectError(error.OverFlow, Map.monsterAt(map, .{ 20, 0 }));
}

test "ask about a character on the map" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer Map.deinit(map);
    try std.testing.expect(try Map.charAt(map, .{ 0, 0 }) == ' ');
}

test "ask about invalid character on the map" {
    const map: *Map = try Map.init(std.testing.allocator, 10, 10);
    defer Map.deinit(map);
    try std.testing.expectError(error.OverFlow, Map.charAt(map, .{ 20, 0 }));
    try std.testing.expectError(error.OverFlow, Map.charAt(map, .{ 0, 20 }));
}

test "draw an invalid room" {
    const map: *Map = try Map.init(std.testing.allocator, 20, 20);
    defer Map.deinit(map);

    try std.testing.expectError(error.OverFlow, Map.drawRoom(map, .{ 15, 15 }, .{ 4, 18 }));
    try std.testing.expectError(error.OverFlow, Map.drawRoom(map, .{ 15, 15 }, .{ 18, 4 }));
}

test "draw an oversize room" {
    const map: *Map = try Map.init(std.testing.allocator, 20, 20);
    defer Map.deinit(map);

    try std.testing.expectError(error.OverFlow, Map.drawRoom(map, .{ 0, 0 }, .{ 0, 100 }));
    try std.testing.expectError(error.OverFlow, Map.drawRoom(map, .{ 0, 0 }, .{ 100, 0 }));
}

test "draw a valid room and test corners" {
    const map: *Map = try Map.init(std.testing.allocator, 50, 50);
    defer Map.deinit(map);

    try Map.drawRoom(map, .{ 10, 10 }, .{ 20, 20 });
    // Corners are '-'
    try std.testing.expect(try Map.charAt(map, .{ 10, 10 }) == '-');
    try std.testing.expect(try Map.charAt(map, .{ 20, 10 }) == '-');
    try std.testing.expect(try Map.charAt(map, .{ 10, 20 }) == '-');
    try std.testing.expect(try Map.charAt(map, .{ 20, 20 }) == '-');
    try std.testing.expect(try Map.charAt(map, .{ 19, 19 }) == '.');
    try std.testing.expect(try Map.charAt(map, .{ 11, 11 }) == '.');
    try std.testing.expect(try Map.charAt(map, .{ 11, 19 }) == '.');
    try std.testing.expect(try Map.charAt(map, .{ 19, 11 }) == '.');
}

// EOF
