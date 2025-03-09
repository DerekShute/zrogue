const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Grid = @import("utils/grid.zig").Grid;
const Item = @import("item.zig").Item;
const Manager = @import("utils/list_manager.zig").Manager;
const Thing = @import("thing.zig").Thing;
const zrogue = @import("zrogue.zig");
const Pos = zrogue.Pos;
const Region = zrogue.Region;
const ZrogueError = zrogue.ZrogueError;
const MapTile = zrogue.MapTile;

// ===================
//
// Item Management on map
//
const ItemManager = Manager(Item);

// ===================
//
// Spot on the map
//
const Place = struct {
    tile: MapTile = .unknown,
    flags: packed struct {
        known: bool,
        // TODO: 'has object'
    },
    monst: ?*Thing,

    // Constructor, probably not idiomatic

    pub fn config(self: *Place) void {
        self.tile = .wall;
        self.flags = .{ .known = false };
        self.monst = null;
    }

    // Methods

    pub fn getTile(self: *Place) MapTile {
        // TODO: this probably falls apart when monsters are on list
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
            return error.AlreadyInUse;
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
    r: Region,
    flags: packed struct {
        lit: bool,
    },

    // Constructor

    pub fn config(tl: Pos, br: Pos) !Room {
        // (0,0) - (0,0) is reserved as the special 'uninitialized' room
        return .{
            .r = try Region.config(tl, br),
            .flags = .{
                .lit = true,
            },
        };
    }

    // Methods

    pub fn getRegion(self: *Room) Region {
        return self.r;
    }

    pub fn getMinX(self: *Room) Pos.Dim {
        const min = self.r.getMin();
        return min.getX();
    }

    pub fn getMaxX(self: *Room) Pos.Dim {
        const max = self.r.getMax();
        return max.getX();
    }

    pub fn getMinY(self: *Room) Pos.Dim {
        const min = self.r.getMin();
        return min.getY();
    }

    pub fn getMaxY(self: *Room) Pos.Dim {
        const max = self.r.getMax();
        return max.getY();
    }

    pub fn isLit(self: *Room) bool {
        return self.flags.lit;
    }

    pub fn setDark(self: *Room) void {
        self.flags.lit = false;
    }

    pub fn isInside(self: *Room, p: Pos) bool {
        if ((p.getX() < self.getMinX()) or (p.getX() > self.getMaxX()) or (p.getY() < self.getMinY()) or (p.getY() > self.getMaxY())) {
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
                    try m.setTile(startx, @intCast(y), .wall);
                }
            }

            fn horiz(m: *Map, starty: Pos.Dim, xrange: [2]Pos.Dim) !void {
                for (@intCast(xrange[0])..@intCast(xrange[1] + 1)) |x| {
                    try m.setTile(@intCast(x), starty, .wall);
                }
            }

            fn field(m: *Map, start: Pos, limit: Pos) !void {
                var r = try Region.config(start, limit);
                var ri = r.iterator();
                while (ri.next()) |pos| {
                    try m.setTile(pos.getX(), pos.getY(), .floor);
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
pub const Map = struct {
    const PlaceGrid = Grid(Place);

    allocator: std.mem.Allocator,
    items: ItemManager,
    places: PlaceGrid,
    rooms: []Room,
    height: Pos.Dim,
    width: Pos.Dim,
    roomsx: Pos.Dim,
    roomsy: Pos.Dim,

    // Allocate and teardown

    pub fn config(allocator: std.mem.Allocator, width: Pos.Dim, height: Pos.Dim, roomsx: Pos.Dim, roomsy: Pos.Dim) !Map {
        if ((height <= 0) or (width <= 0) or (roomsx <= 0) or (roomsy <= 0)) {
            return error.Underflow;
        }

        const places = try PlaceGrid.config(allocator, @intCast(width), @intCast(height));
        errdefer places.deinit();

        var p = places.iterator();
        while (p.next()) |place| {
            place.config();
        }

        const rooms = try allocator.alloc(Room, @intCast(roomsx * roomsy));
        errdefer allocator.free(rooms);
        for (rooms) |*room| {
            room.* = try Room.config(Pos.init(0, 0), Pos.init(0, 0));
        }

        return .{
            .allocator = allocator,
            .items = ItemManager.config(allocator),
            .height = height,
            .width = width,
            .places = places,
            .rooms = rooms,
            .roomsx = roomsx,
            .roomsy = roomsy,
        };
    }

    pub fn deinit(self: *Map) void {
        const allocator = self.allocator;
        self.items.deinit();
        self.places.deinit();
        allocator.free(self.rooms);
    }

    // Utility

    fn toPlace(self: *Map, x: Pos.Dim, y: Pos.Dim) !*Place {
        return try self.places.find(@intCast(x), @intCast(y));
    }

    // Internal structs

    const Corridor = struct {
        cur: Pos,
        dest: Pos,
        mid: Pos.Dim,

        pub fn config(s: Pos, e: Pos, m: Pos.Dim) Corridor {
            return .{
                .cur = s,
                .dest = e,
                .mid = m,
            };
        }

        pub fn nextSouth(self: *Corridor) ?Pos {
            // Southward tunnel

            const ret = self.cur;
            var x = self.cur.getX();
            var y = self.cur.getY();

            if (y > self.dest.getY()) {
                return null;
            }

            if (y == self.mid) { // Move South unless at midpoint
                if (x == self.dest.getX()) {
                    y = y + 1;
                } else if (x < self.dest.getX()) {
                    x = x + 1;
                } else {
                    x = x - 1;
                }
            } else {
                y = y + 1;
            }

            self.cur = Pos.init(x, y);
            return ret;
        }

        pub fn nextEast(self: *Corridor) ?Pos {
            // Eastward tunnel

            const ret = self.cur;
            var x = self.cur.getX();
            var y = self.cur.getY();

            if (x > self.dest.getX()) {
                return null;
            }

            if (x == self.mid) { // Move East unless at midpoint
                if (y == self.dest.getY()) {
                    x = x + 1;
                } else if (y < self.dest.getY()) {
                    y = y + 1;
                } else {
                    y = y - 1;
                }
            } else {
                x = x + 1;
            }

            self.cur = Pos.init(x, y);
            return ret;
        }
    };

    // Methods

    pub fn getHeight(self: *Map) Pos.Dim {
        return self.height;
    }

    pub fn getWidth(self: *Map) Pos.Dim {
        return self.width;
    }

    pub fn getTile(self: *Map, x: Pos.Dim, y: Pos.Dim) !MapTile {
        const place = try self.toPlace(x, y);
        var tile = place.getTile();

        // Monster tile takes precedence and we only see an object if it is
        // on the visible floor
        if (tile == .floor) {
            // TODO: set bit in Place to see if even worth looking
            if (self.getItem(Pos.init(x, y))) |item| {
                tile = item.getTile();
            }
        }
        return tile;
    }

    pub fn setTile(self: *Map, x: Pos.Dim, y: Pos.Dim, tile: MapTile) !void {
        const place = try self.toPlace(x, y);
        place.setTile(tile);
    }

    pub fn passable(self: *Map, x: Pos.Dim, y: Pos.Dim) !bool {
        const place = try self.toPlace(x, y);
        return place.passable();
    }

    pub fn dig(self: *Map, start: Pos, end: Pos) !void {
        // Inclusive of start and end positions

        // TODO: order for easterly or southerly dig.  Does not test for
        // directly below
        if (self.isRoomAdjacent(start, end)) { // next : dig East
            const mid = @divTrunc(start.getX() + end.getX(), 2);
            var i = Corridor.config(start, end, mid);
            while (i.nextEast()) |p| {
                const place = try self.toPlace(p.getX(), p.getY());
                place.setTile(MapTile.floor);
            }
        } else { // below : dig South
            const mid = @divTrunc(start.getY() + end.getY(), 2);
            var i = Corridor.config(start, end, mid);
            while (i.nextSouth()) |p| {
                const place = try self.toPlace(p.getX(), p.getY());
                place.setTile(MapTile.floor);
            }
        }

        try self.setTile(start.getX(), start.getY(), .door);
        try self.setTile(end.getX(), end.getY(), .door);
    }

    // items

    pub fn addItem(self: *Map, item: Item) !void {
        _ = try self.items.node(item);
    }

    pub fn getItem(self: *Map, pos: Pos) ?*Item {
        // TODO: first found
        var it = self.items.iterator();

        while (it.next()) |item| {
            if (pos.eql(item.getPos())) {
                return item;
            }
        }
        return null;
    }

    pub fn removeItem(self: *Map, item: *Item) void {
        self.items.deinitNode(item);
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
        var r = try Region.config(Pos.init(x, y), Pos.init(maxx, maxy));
        var ri = r.iterator();
        while (ri.next()) |pos| {
            const place = try self.toPlace(pos.getX(), pos.getY());
            place.setKnown(true);
        }
    }

    // rooms

    fn getRoomNum(self: *Map, p: Pos) ?usize {
        if ((p.getX() < 0) or (p.getY() < 0)) {
            return null;
        }

        const xsize = @divTrunc(self.width, self.roomsx); // spaces per column
        const ysize = @divTrunc(self.height, self.roomsy); // spaces per row
        const column = @divTrunc(p.getX(), xsize);
        const row = @divTrunc(p.getY(), ysize);
        const loc: usize = @intCast(row * self.roomsy + column);

        if (loc > self.rooms.len) {
            return null;
        }

        return loc;
    }

    fn isRoomAdjacent(self: *Map, p1: Pos, p2: Pos) bool {
        const r1 = self.getRoomNum(p1);
        const r2 = self.getRoomNum(p2);

        if (r1) |r1num| {
            if (r2) |r2num| {
                if ((r1num > r2num) and (r1num - r2num == 1)) {
                    return true;
                } else if ((r2num > r1num) and (r2num - r1num == 1)) {
                    return true;
                }
            }
        }
        return false;
    }

    fn getRoom(self: *Map, p: Pos) ?*Room {
        if (self.getRoomNum(p)) |loc| {
            return &self.rooms[loc];
        }
        return null;
    }

    pub fn inRoom(self: *Map, p: Pos) bool {
        if (self.getRoom(p)) |room| {
            return room.isInside(p);
        }
        return false; // TODO ugh
    }

    pub fn getRoomRegion(self: *Map, p: Pos) !Region {
        if (self.getRoom(p)) |room| {
            return room.getRegion();
        }
        return ZrogueError.OutOfBounds;
    }

    pub fn addRoom(self: *Map, room: Room) ZrogueError!void {
        var r = room; // force to var reference

        // TODO We will need to support 1x1 "removed" rooms eventually...
        if ((r.getMaxX() - r.getMinX() <= 1) or (r.getMaxY() - r.getMinY() <= 1)) {
            return ZrogueError.IndexOverflow;
        }

        // Rooms have a validated Region inside, so no need to test...
        // ...unless paranoid

        // getRoom() validates coordinates

        // Make sure that the region fits in one 'grid' location
        var sr = self.getRoom(Pos.init(r.getMinX(), r.getMinY()));
        const sr2 = self.getRoom(Pos.init(r.getMaxX(), r.getMaxY()));
        if ((sr == null) or (sr2 == null)) {
            return ZrogueError.OutOfBounds;
        } else if (sr != sr2) {
            return ZrogueError.OutOfBounds;
        }

        // sr proven non-null above

        if (sr.?.getMaxX() != 0) { // already set?
            return ZrogueError.AlreadyInUse;
        }

        sr.?.* = r;
        try sr.?.draw(self);
    }

    pub fn isLit(self: *Map, p: Pos) bool {
        if (self.getRoom(p)) |room| {
            if (room.isInside(p)) {
                return room.isLit();
            }
        }
        return false; // TODO ugh
    }

    pub fn revealRoom(self: *Map, p: Pos) !void {
        if (self.getRoom(p)) |room| {
            if (room.isInside(p)) {
                try room.reveal(self);
            }
        } else {
            return ZrogueError.OutOfBounds;
        }
    }
};

//
// Unit Tests
//

// Rooms

test "create a room and test properties" {
    var room: Room = try Room.config(Pos.init(10, 10), Pos.init(20, 20));

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
    var map: Map = try Map.config(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(5, 5), Pos.init(10, 10));
    try map.addRoom(r1);
    try expect(map.inRoom(Pos.init(7, 7)) == true);
    try expect(map.inRoom(Pos.init(19, 19)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
}

test "reveal room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(5, 5), Pos.init(10, 10));
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
    var map: Map = try Map.config(std.testing.allocator, 100, 50, 1, 1);
    defer map.deinit();

    try map.addRoom(try Room.config(Pos.init(10, 10), Pos.init(20, 20)));

    try std.testing.expect(map.getHeight() == 50);
    try std.testing.expect(map.getWidth() == 100);

    try expect(map.isLit(Pos.init(15, 15)) == true);
    // TODO set room dark, then ask again

    try expect(try map.isKnown(15, 15) == false);
    try expect(try map.getTile(0, 0) == .wall);
    try expect(try map.getTile(10, 10) == .wall);

    try map.setKnown(15, 15, true);
    try expect(try map.isKnown(15, 15) == true);
    try map.setKnown(15, 15, false);
    try expect(try map.isKnown(15, 15) == false);

    // Explicit set tile inside a known room
    try map.setTile(17, 17, .wall);
    try expect(try map.getTile(17, 17) == .wall);

    try map.setTile(18, 18, .door);
    try expect(try map.getTile(18, 18) == .door);

    try map.setRegionKnown(12, 12, 15, 15);
    try expect(try map.isKnown(12, 12) == true);
    try expect(try map.isKnown(15, 15) == true);
    try expect(try map.isKnown(16, 16) == false);
    try expect(try map.isKnown(11, 11) == false);
}

test "fails to allocate places of map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, Map.config(failing.allocator(), 10, 10, 1, 1));
}

test "fails to allocate rooms of map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, Map.config(failing.allocator(), 10, 10, 10, 10));
}

test "allocate invalid size map" {
    const allocator = std.testing.allocator;
    try expectError(error.Underflow, Map.config(allocator, 0, 10, 10, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, 0, 10, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, 10, 0, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, 10, 10, 0));
    try expectError(error.Underflow, Map.config(allocator, -1, 10, 10, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, -1, 10, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, 10, -1, 10));
    try expectError(error.Underflow, Map.config(allocator, 10, 10, 10, -1));
}

test "ask about valid map location" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();

    const thing = try map.getMonster(4, 4);
    try expect(thing == null); // Nothing there
}

test "ask about thing at invalid map location" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();
    try expectError(ZrogueError.IndexOverflow, map.getMonster(0, 20));
    try expectError(ZrogueError.IndexOverflow, map.getMonster(20, 0));
}

test "ask about invalid character on the map" {
    var map: Map = try Map.config(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();
    try expectError(ZrogueError.IndexOverflow, map.getTile(20, 0));
    try expectError(ZrogueError.IndexOverflow, map.getTile(0, 20));
}

test "Create an invalid room" {

    // Room API prevents describing invalid rooms

    const r1 = Room.config(Pos.init(15, 15), Pos.init(4, 18));
    try expectError(ZrogueError.OutOfBounds, r1);
    const r2 = Room.config(Pos.init(15, 15), Pos.init(18, 4));
    try expectError(ZrogueError.OutOfBounds, r2);
}

test "inquire about room at invalid location" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    try expectError(ZrogueError.OutOfBounds, map.getRoomRegion(Pos.init(21, 21)));
    try expectError(ZrogueError.OutOfBounds, map.getRoomRegion(Pos.init(-1, -1)));
    try expectError(ZrogueError.OutOfBounds, map.revealRoom(Pos.init(-1, -1)));
    try expectError(ZrogueError.OutOfBounds, map.revealRoom(Pos.init(100, 100)));

    // The rest are inquiries that we default to 'false' for insane callers
    // commence groaning now

    try expect(map.inRoom(Pos.init(100, 100)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
    try expect(map.isLit(Pos.init(-1, -1)) == false);
    try expect(map.isLit(Pos.init(100, 100)) == false);
}

test "draw an oversize room" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(0, 0), Pos.init(0, 100));
    try expectError(ZrogueError.IndexOverflow, map.addRoom(r1));
    const r2 = try Room.config(Pos.init(0, 0), Pos.init(100, 0));
    try expectError(ZrogueError.IndexOverflow, map.addRoom(r2));
}

test "create a room that breaks the grid" {
    var map: Map = try Map.config(std.testing.allocator, 100, 100, 2, 2);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(10, 10), Pos.init(90, 90));
    try expectError(ZrogueError.OutOfBounds, map.addRoom(r1));
}

test "one tile (removed) room" {
    // TODO This concept is necessary for mapgen but causes problems now

    var map: Map = try Map.config(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(5, 5), Pos.init(5, 5));
    try expectError(ZrogueError.IndexOverflow, map.addRoom(r1));
}

test "map multiple rooms" {
    var map: Map = try Map.config(std.testing.allocator, 100, 100, 2, 2);
    defer map.deinit();

    const r1 = try Room.config(Pos.init(0, 0), Pos.init(10, 10));
    try map.addRoom(r1);
    const r2 = try Room.config(Pos.init(60, 20), Pos.init(70, 30));
    try map.addRoom(r2);
}

test "map invalid multiple rooms" {
    var map: Map = try Map.config(std.testing.allocator, 100, 100, 2, 2);
    defer map.deinit();

    // Can't overlap the rooms and can't overwrite

    const r1 = try Room.config(Pos.init(0, 0), Pos.init(10, 10));
    try map.addRoom(r1);
    try expectError(ZrogueError.AlreadyInUse, map.addRoom(r1));
    const r2 = try Room.config(Pos.init(1, 1), Pos.init(12, 12));
    try expectError(ZrogueError.AlreadyInUse, map.addRoom(r2));
}

// Corridors

test "dig corridors" {
    var map: Map = try Map.config(std.testing.allocator, 40, 40, 2, 2);
    defer map.deinit();

    // These don't have to make sense as part of actual rooms

    // Eastward dig
    try map.dig(Pos.init(4, 4), Pos.init(20, 10));
    try expect(try map.getTile(12, 7) == .floor); // halfway
    try expect(try map.getTile(12, 4) == .floor);
    try expect(try map.getTile(12, 10) == .floor);
    try expect(try map.getTile(4, 4) == .door);
    try expect(try map.getTile(20, 10) == .door);

    // Southward dig
    try map.dig(Pos.init(10, 8), Pos.init(3, 14));
    try expect(try map.getTile(6, 11) == .floor); // halfway
    try expect(try map.getTile(3, 11) == .floor);
    try expect(try map.getTile(10, 11) == .floor);
    try expect(try map.getTile(10, 8) == .door);
    try expect(try map.getTile(3, 14) == .door);
}

test "dig unusual corridors" {
    var map: Map = try Map.config(std.testing.allocator, 20, 20, 2, 2);
    defer map.deinit();

    try map.dig(Pos.init(5, 10), Pos.init(5, 12)); // One tile
    try expect(try map.getTile(5, 11) == .floor);

    try map.dig(Pos.init(10, 5), Pos.init(15, 5)); // straight East
    try expect(try map.getTile(11, 5) == .floor);
    try expect(try map.getTile(13, 5) == .floor);
    try expect(try map.getTile(14, 5) == .floor);

    try map.dig(Pos.init(16, 8), Pos.init(16, 13)); // straight South
    try expect(try map.getTile(16, 9) == .floor);
    try expect(try map.getTile(16, 10) == .floor);
    try expect(try map.getTile(16, 12) == .floor);
}

// Items

test "put item on map" {
    var map: Map = try Map.config(std.testing.allocator, 50, 50, 1, 1);
    defer map.deinit();

    try map.addItem(Item.config(25, 25, .gold));

    const item = map.getItem(Pos.init(25, 25));
    if (item) |i| { // Convenience
        try expect(i.getTile() == .gold);
        const p = i.getPos();
        try expect(p.getX() == 25);
        try expect(p.getY() == 25);
    } else {
        unreachable;
    }

    try map.setTile(25, 25, .floor); // Must be floor to show it
    try expect(try map.getTile(25, 25) == .gold);

    // Monster's tile has precedence

    var thing = Thing{ .xy = Pos.init(0, 0), .tile = .player };
    try map.setMonster(&thing, 25, 25);
    try expect(try map.getTile(25, 25) == .player);
}

// Monsters

test "putting monsters places" {
    var map: Map = try Map.config(std.testing.allocator, 50, 50, 1, 1);
    defer map.deinit();
    var thing = Thing{ .xy = Pos.init(0, 0), .tile = .player };
    var thing2 = Thing{ .xy = Pos.init(0, 0), .tile = .player };

    var m: *Map = &map;
    try m.setMonster(&thing, 10, 10);
    try expect(thing.atXY(10, 10));

    try expectError(error.AlreadyInUse, map.setMonster(&thing2, 10, 10));
}

// Visualize

const genFields = @import("utils/visual.zig").genFields;

pub var map_fields = genFields(Map);
pub var place_fields = genFields(Place);
pub var room_fields = genFields(Room);
pub var items_fields = genFields(ItemManager);

// EOF
