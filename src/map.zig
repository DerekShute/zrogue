//!
//! Everything maps - map tiles, rooms, items on the map, and so forth
//!

const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const Grid = @import("utils/grid.zig").Grid;
const Item = @import("item.zig").Item;
const Manager = @import("utils/list_manager.zig").Manager;
const Thing = @import("thing.zig").Thing;
const Feature = @import("Feature.zig");
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

// Feature Management
const FeatureManager = Manager(Feature);

// ===================
//
// Spot on the map
//
const Place = struct {
    tile: MapTile = .unknown,
    monst: ?*Thing = undefined,
    item: ?*Item = undefined,
    feature: ?*Feature = undefined,

    // Constructor, probably not idiomatic

    pub fn config(self: *Place) void {
        self.tile = .wall;
        self.monst = null;
        self.item = null;
        self.feature = null;
    }

    // Methods

    pub fn getTile(self: *Place) MapTile {
        return self.tile;
    }

    pub fn passable(self: *Place) bool {
        return self.tile.isPassable();
    }

    pub fn setTile(self: *Place, to: MapTile) void {
        self.tile = to;
    }

    // Item at place

    pub fn getItem(self: *Place) ?*Item {
        return self.item;
    }

    pub fn setItem(self: *Place, new: *Item) !void {
        if (self.item) |_| {
            return error.AlreadyInUse;
        }
        self.item = new;
    }

    pub fn removeItem(self: *Place) void {
        if (self.item) |_| {
            self.item = null;
        }
    }

    // Monster at place

    pub fn getMonster(self: *Place) ?*Thing {
        return self.monst;
    }

    pub fn setMonster(self: *Place, new_monst: *Thing) !void {
        if (self.monst) |_| {
            return error.AlreadyInUse;
        }
        self.monst = new_monst;
    }

    pub fn removeMonster(self: *Place) void {
        if (self.monst) |_| {
            self.monst = null;
        }
    }

    // Feature at place

    pub fn addFeature(self: *Place, new: *Feature) !void {
        if (self.feature) |_| {
            return error.AlreadyInUse;
        }
        self.feature = new;
    }

    pub fn removeFeature(self: *Place) void {
        self.feature = null;
    }

    pub fn getFeature(self: *Place) ?*Feature {
        return self.feature;
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
        gone: bool,
    },

    // Constructor

    pub fn config(tl: Pos, br: Pos) Room {
        // (0,0) - (0,0) is reserved as the special 'uninitialized' room
        return .{
            .r = Region.config(tl, br),
            .flags = .{
                .lit = true,
                .gone = false,
            },
        };
    }

    // Methods

    pub fn isLit(self: *Room) bool {
        return self.flags.lit;
    }

    pub fn setDark(self: *Room) void {
        self.flags.lit = false;
    }

    pub fn setGone(self: *Room) void {
        self.flags.gone = true;
    }

    pub usingnamespace Region.Methods(@This());
};

// ===================
//
// Map
//
pub const Map = struct {
    const PlaceGrid = Grid(Place);

    allocator: std.mem.Allocator,
    items: ItemManager,
    features: FeatureManager,
    places: PlaceGrid,
    rooms: []Room,
    height: Pos.Dim,
    width: Pos.Dim,
    roomsx: Pos.Dim,
    roomsy: Pos.Dim,
    level: usize = 1,

    // Allocate and teardown

    pub fn init(allocator: std.mem.Allocator, width: Pos.Dim, height: Pos.Dim, roomsx: Pos.Dim, roomsy: Pos.Dim) !*Map {
        if ((height <= 0) or (width <= 0) or (roomsx <= 0) or (roomsy <= 0)) {
            return error.Underflow;
        }
        const m: *Map = try allocator.create(Map);
        errdefer allocator.destroy(m);

        const places = try PlaceGrid.config(allocator, @intCast(width), @intCast(height));
        errdefer places.deinit();

        var p = places.iterator();
        while (p.next()) |place| {
            place.config();
        }

        const rooms = try allocator.alloc(Room, @intCast(roomsx * roomsy));
        errdefer allocator.free(rooms);
        for (rooms) |*room| {
            room.* = Room.config(Pos.init(0, 0), Pos.init(0, 0));
        }

        m.allocator = allocator;
        m.items = ItemManager.config(allocator);
        m.features = FeatureManager.config(allocator);
        m.height = height;
        m.width = width;
        m.places = places;
        m.rooms = rooms;
        m.roomsx = roomsx;
        m.roomsy = roomsy;

        // Can call Map.deinit after this point

        return m;
    }

    pub fn deinit(self: *Map) void {
        const allocator = self.allocator;
        self.items.deinit();
        self.features.deinit();
        self.places.deinit();
        allocator.free(self.rooms);
        allocator.destroy(self);
    }

    // Utility

    fn toPlace(self: *Map, x: Pos.Dim, y: Pos.Dim) !*Place {
        return try self.places.find(@intCast(x), @intCast(y));
    }

    // Methods

    pub fn getHeight(self: *Map) Pos.Dim {
        return self.height;
    }

    pub fn getWidth(self: *Map) Pos.Dim {
        return self.width;
    }

    pub fn getDepth(self: *Map) usize {
        return self.level;
    }

    pub fn getFloorTile(self: *Map, p: Pos) !MapTile {
        const place = try self.toPlace(p.getX(), p.getY());
        return place.getTile();
    }

    pub fn getMonsterTile(self: *Map, p: Pos) !MapTile {
        const place = try self.toPlace(p.getX(), p.getY());
        if (place.getMonster()) |m| {
            return m.getTile();
        }
        return .unknown;
    }

    pub fn getItemTile(self: *Map, p: Pos) !MapTile {
        const place = try self.toPlace(p.getX(), p.getY());
        if (place.getItem()) |i| {
            return i.getTile();
        }
        return .unknown;
    }

    pub fn setTile(self: *Map, p: Pos, tile: MapTile) !void {
        const place = try self.toPlace(p.getX(), p.getY());
        place.setTile(tile);
    }

    pub fn passable(self: *Map, p: Pos) !bool {
        const place = try self.toPlace(p.getX(), p.getY());
        return place.passable();
    }

    // items

    pub fn addItem(self: *Map, item: Item) !void {
        // FUTURE: this creates the item from the copy sent in
        const i = try self.items.node(item);
        errdefer self.items.deinitNode(i);

        const place = try self.toPlace(i.getX(), i.getY());
        try place.setItem(i);
    }

    pub fn getItem(self: *Map, pos: Pos) !?*Item {
        const place = try self.toPlace(pos.getX(), pos.getY());
        return place.getItem();
    }

    pub fn removeItem(self: *Map, item: *Item) !void {
        // FUTURE: this deletes the item
        const place = try self.toPlace(item.getX(), item.getY());
        place.removeItem();
        self.items.deinitNode(item);
    }

    // monsters

    pub fn getMonster(self: *Map, x: Pos.Dim, y: Pos.Dim) !?*Thing {
        const place = try self.toPlace(x, y);
        return place.getMonster();
    }

    pub fn setMonster(self: *Map, monst: *Thing) !void {
        const place = try self.toPlace(monst.getX(), monst.getY());
        try place.setMonster(monst);
    }

    pub fn removeMonster(self: *Map, p: Pos) !void {
        const place = try self.toPlace(p.getX(), p.getY());
        place.removeMonster();
    }

    // features

    pub fn getFeature(self: *Map, p: Pos) !?*Feature {
        const place = try self.toPlace(p.getX(), p.getY());
        return place.getFeature();
    }

    pub fn addFeature(self: *Map, new: Feature) !void {
        // FUTURE: this creates the item from the copy sent in
        const f = try self.features.node(new);
        errdefer self.features.deinitNode(f);

        const p = f.getPos(); // TODO: this is lame
        const place = try self.toPlace(p.getX(), p.getY());
        try place.addFeature(f);
    }

    pub fn removeFeature(self: *Map, f: *Feature) !void {
        const p = f.getPos(); // TODO: this is lame
        const place = try self.toPlace(p.getX(), p.getY());
        place.removeFeature();
        self.features.deinitNode(f); // Destructor
    }

    // rooms

    fn getRoomNum(self: *Map, p: Pos) ?usize {
        if ((p.getX() < 0) or (p.getY() < 0)) {
            return null;
        } else if ((p.getX() >= self.width) or (p.getY() >= self.height)) {
            return null;
        }

        const xsize = @divTrunc(self.width, self.roomsx); // spaces per column
        const ysize = @divTrunc(self.height, self.roomsy); // spaces per row
        const column = @divTrunc(p.getX(), xsize);
        const row = @divTrunc(p.getY(), ysize);
        const loc: usize = @intCast(row * self.roomsy + column);

        if (loc >= self.rooms.len) {
            return null;
        }

        return loc;
    }

    // TODO Future: getRoomNum is a mapgen thing
    fn getRoom(self: *Map, p: Pos) ?*Room {
        if (self.getRoomNum(p)) |loc| {
            return &self.rooms[loc];
        }
        return null;
    }

    fn getInRoom(self: *Map, p: Pos) ?*Room {
        // If in the room, return it, else null
        if (self.getRoom(p)) |room| {
            if (room.isInside(p)) {
                return room;
            }
        } // else ugh

        return null;
    }

    pub fn inRoom(self: *Map, p: Pos) bool {
        if (self.getRoom(p)) |room| {
            return room.isInside(p);
        }
        return false; // TODO: ugh
    }

    pub fn getRoomRegion(self: *Map, p: Pos) !Region {
        if (self.getRoom(p)) |room| {
            return room.getRegion();
        }
        return ZrogueError.OutOfBounds;
    }

    pub fn addRoom(self: *Map, room: Room) void {
        var r = room; // force to var reference

        // Minimum is 3x3 : two walls plus one tile
        if ((r.getMaxX() - r.getMinX() < 2) or (r.getMaxY() - r.getMinY() < 2)) {
            @panic("addRoom: Invalid room");
        }

        // Rooms have a validated Region inside, so no need to test...
        // ...unless paranoid

        // getRoom() validates coordinates

        // Make sure that the region fits in one 'grid' location
        var sr = self.getRoom(Pos.init(r.getMinX(), r.getMinY()));
        const sr2 = self.getRoom(Pos.init(r.getMaxX(), r.getMaxY()));
        if (sr == null) {
            @panic("addRoom: room minimum off of map");
        } else if (sr2 == null) {
            @panic("addRoom: room maximum off of map");
        } else if (sr != sr2) {
            @panic("addRoom: room spans a room box");
        }

        // sr proven non-null above

        if (sr.?.getMaxX() != 0) {
            @panic("addRoom: Room already defined");
        }

        sr.?.* = r;
    }

    pub fn isLit(self: *Map, p: Pos) bool {
        if (self.getRoom(p)) |room| {
            if (room.isInside(p)) {
                return room.isLit();
            }
        }
        return false; // TODO: ugh
    }

    // Reveal a room to the entity in question
    pub fn reveal(self: *Map, entity: *Thing) void {
        if (self.getInRoom(entity.getPos())) |room| {
            if (room.isLit()) {
                // FUTURE: shaped rooms
                entity.setKnown(room.getRegion(), true);
                entity.setVisible(room.getRegion());
                return;
            }
        }

        // Fallback: only surroundings

        const tl = Pos.add(entity.getPos(), Pos.init(-1, -1));
        const br = Pos.add(entity.getPos(), Pos.init(1, 1));
        entity.setKnown(Region.config(tl, br), true);
        entity.setVisible(Region.config(tl, br));
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
    try expect(room.isInside(Pos.init(15, 15))); // Smoke: methods available

    try expect(room.isLit() == true);
    room.setDark();
    try expect(room.isLit() == false);
}

test "add a room and ask about it" {
    var map = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    const r1 = Room.config(Pos.init(5, 5), Pos.init(10, 10));
    map.addRoom(r1);
    try expect(map.inRoom(Pos.init(7, 7)) == true);
    try expect(map.inRoom(Pos.init(19, 19)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
}

// Map

test "map smoke test" {
    var map = try Map.init(std.testing.allocator, 100, 50, 1, 1);
    defer map.deinit();

    map.addRoom(Room.config(Pos.init(10, 10), Pos.init(20, 20)));
    try map.setTile(Pos.init(15, 15), .stairs_down);
    try std.testing.expect(try map.getFloorTile(Pos.init(15, 15)) == .stairs_down);
    try map.setTile(Pos.init(16, 16), .stairs_up);
    try std.testing.expect(try map.getFloorTile(Pos.init(16, 16)) == .stairs_up);

    try std.testing.expect(map.getHeight() == 50);
    try std.testing.expect(map.getWidth() == 100);
}

test "fails to allocate map" { // first allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    try expectError(error.OutOfMemory, Map.init(allocator, 10, 10, 1, 1));
}

test "fails to allocate places of map" { // second allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const allocator = failing.allocator();
    try expectError(error.OutOfMemory, Map.init(allocator, 10, 10, 1, 1));
}

test "fails to allocate rooms of map" { // third allocation attempt
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 2 });
    const allocator = failing.allocator();
    try expectError(error.OutOfMemory, Map.init(allocator, 10, 10, 10, 10));
}

test "allocate invalid size map" {
    const allocator = std.testing.allocator;
    try expectError(error.Underflow, Map.init(allocator, 0, 10, 10, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, 0, 10, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, 10, 0, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, 10, 10, 0));
    try expectError(error.Underflow, Map.init(allocator, -1, 10, 10, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, -1, 10, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, 10, -1, 10));
    try expectError(error.Underflow, Map.init(allocator, 10, 10, 10, -1));
}

test "ask about valid map location" {
    var map = try Map.init(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();

    const thing = try map.getMonster(4, 4);
    try expect(thing == null); // Nothing there
}

test "ask about thing at invalid map location" {
    var map = try Map.init(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();
    try expectError(ZrogueError.IndexOverflow, map.getMonster(0, 20));
    try expectError(ZrogueError.IndexOverflow, map.getMonster(20, 0));
}

test "ask about invalid character on the map" {
    var map = try Map.init(std.testing.allocator, 10, 10, 1, 1);
    defer map.deinit();
    try expectError(ZrogueError.IndexOverflow, map.getFloorTile(Pos.init(20, 0)));
    try expectError(ZrogueError.IndexOverflow, map.getFloorTile(Pos.init(0, 20)));
}

//
// Attempting to add an invalid room is prevented by a panic so we can get to
// the bottom of why it was even attempted.  This includes:
//
// * rooms that would go off the map
// * rooms that cross 'room boundaries'
// * rooms smaller than a useful minimum (3x3)
// * rooms that have already been described
//

test "inquire about room at invalid location" {
    var map = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit();

    try expectError(ZrogueError.OutOfBounds, map.getRoomRegion(Pos.init(21, 21)));
    try expectError(ZrogueError.OutOfBounds, map.getRoomRegion(Pos.init(-1, -1)));

    try expect(map.getRoomNum(Pos.init(19, 0)) == 0);
    try expect(map.getRoomNum(Pos.init(20, 0)) == null);
    try expect(map.getRoomNum(Pos.init(0, 20)) == null);
    try expect(map.getRoomNum(Pos.init(0, 19)) == 0);

    // The rest are inquiries that we default to 'false' for insane callers
    // commence groaning now

    try expect(map.inRoom(Pos.init(20, 0)) == false);
    try expect(map.inRoom(Pos.init(100, 100)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
    try expect(map.inRoom(Pos.init(-1, -1)) == false);
    try expect(map.isLit(Pos.init(-1, -1)) == false);
    try expect(map.isLit(Pos.init(100, 100)) == false);
}

test "map multiple rooms" {
    var map = try Map.init(std.testing.allocator, 100, 100, 2, 2);
    defer map.deinit();

    const r1 = Room.config(Pos.init(0, 0), Pos.init(10, 10));
    map.addRoom(r1);
    const r2 = Room.config(Pos.init(60, 20), Pos.init(70, 30));
    map.addRoom(r2);
}

// Items

test "put item on map" {
    var map = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer map.deinit();

    const p = Pos.init(25, 25);

    try map.setTile(p, .floor);
    try expect(try map.getFloorTile(p) == .floor);

    try expect(try map.getItemTile(p) == .unknown);
    try map.addItem(Item.config(p.getX(), p.getY(), .gold));
    try expect(try map.getItemTile(p) == .gold);

    const item = try map.getItem(p);
    if (item) |i| { // Convenience
        try expect(i.getTile() == .gold);
        try expect(p.eql(i.getPos()));
    } else {
        unreachable;
    }

    var thing = Thing{ .p = p, .tile = .player };
    try expect(try map.getMonsterTile(p) == .unknown);
    try map.setMonster(&thing);
    try expect(try map.getMonsterTile(p) == .player);
    try map.removeMonster(p);
    try expect(try map.getMonsterTile(p) == .unknown);
}

// Monsters

test "putting monsters places" {
    var map = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer map.deinit();
    var thing = Thing{ .p = Pos.init(10, 10), .tile = .player };
    var thing2 = Thing{ .p = Pos.init(10, 10), .tile = .player };

    try map.setMonster(&thing);
    try expectError(error.AlreadyInUse, map.setMonster(&thing2));
}

// Features

test "putting features places" {
    var map = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer map.deinit();

    var f = Feature{ .pos = Pos.init(10, 10), .vtable = null };
    try map.addFeature(f);
    try expectError(error.AlreadyInUse, map.addFeature(f));
    const f2 = try map.getFeature(f.getPos());
    try expect(f2 != null);
    try map.removeFeature(f2.?);
}

// Visualize

const genFields = @import("utils/visual.zig").genFields;

pub var map_fields = genFields(Map);
pub var place_fields = genFields(Place);
pub var room_fields = genFields(Room);
pub var items_fields = genFields(ItemManager);
pub var features_field = genFields(FeatureManager);

// EOF
