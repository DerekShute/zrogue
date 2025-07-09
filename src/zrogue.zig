//!
//! Common enums and errors
//!
//! This is the base dependency and its existence is a relic of C mentality
//!

const std = @import("std");

//
// Constants relating to display conventions
//

pub const DISPLAY_MINX = 80;
pub const DISPLAY_MINY = 24;

pub const MAPSIZE_X = DISPLAY_MINX;
pub const MAPSIZE_Y = DISPLAY_MINY - 2; // Minus message and stat rows

pub const MESSAGE_MAXSIZE = DISPLAY_MINX;

//
// Input abstraction
//
// REFACTOR: snake case for enums
// REFACTOR: is this an input.zig thing?
// REFACTOR: Partially duplicates ThingAction.type
pub const Command = enum {
    wait,
    quit,
    goNorth, // 'up'/'down' confusing w/r/t stairs
    goEast,
    goSouth,
    goWest,
    ascend,
    descend,
    help,
    takeItem,
    search,
};

//
// Visible thing at map space
//
// TODO Future: union with monster types and objects?
//
pub const MapTile = enum {
    unknown,
    floor,
    wall, // Start of features
    door,
    stairs_down,
    stairs_up, // Last feature
    gold,
    player,

    pub fn isFeature(self: MapTile) bool {
        const s: usize = @intFromEnum(self);
        return switch (s) {
            @intFromEnum(MapTile.wall)...@intFromEnum(MapTile.stairs_up) => true,
            else => false,
        };
    }

    pub fn isPassable(self: MapTile) bool {
        return (self != .wall);
    }
};

//
// Map coordinates and width/height and directional deltas
//
pub const Pos = struct {
    pub const Dim = i16;

    pub const Direction = enum {
        north,
        east,
        south,
        west,
    };

    xy: [2]Dim = .{ -1, -1 },

    pub inline fn init(x: Dim, y: Dim) Pos {
        return .{ .xy = .{ x, y } };
    }

    pub inline fn direct(d: Direction) Pos {
        return switch (d) {
            .north => Pos.init(0, -1),
            .east => Pos.init(1, 0),
            .south => Pos.init(0, 1),
            .west => Pos.init(-1, 0),
        };
    }

    pub inline fn quant(self: Pos) usize {
        return @intCast(self.xy[0] * self.xy[1]);
    }

    pub inline fn getX(self: Pos) Dim {
        return self.xy[0];
    }

    pub inline fn getY(self: Pos) Dim {
        return self.xy[1];
    }

    pub inline fn isDim(self: Pos) bool {
        return ((self.getX() >= 0) and (self.getY() >= 0));
    }

    pub inline fn eql(self: Pos, other: Pos) bool {
        return ((self.getX() == other.getX()) and (self.getY() == other.getY()));
    }

    // Implication is that one of these is a delta
    pub inline fn add(pos1: Pos, pos2: Pos) Pos {
        return Pos.init(pos1.getX() + pos2.getX(), pos1.getY() + pos2.getY());
    }

    // Chebyshev distance
    pub inline fn distance(pos1: Pos, pos2: Pos) Dim {
        const maxx = @abs(pos1.getX() - pos2.getX());
        const maxy = @abs(pos1.getY() - pos2.getY());
        return if (maxx > maxy) @intCast(maxx) else @intCast(maxy);
    }

    //
    // Pos.Methods: mixin for clients of Pos to lift up common functions
    //
    // use this as follows:  pub usingnamespace Pos.Methods(@This());
    //
    pub fn Methods(comptime Self: type) type {

        // assumes a field 'p: Pos' in whatever Self pulls this in

        return struct {
            pub fn getX(self: *Self) Pos.Dim {
                return self.p.getX();
            }

            pub fn getY(self: *Self) Pos.Dim {
                return self.p.getY();
            }

            pub fn getPos(self: *Self) Pos {
                return self.p;
            }

            pub fn setPos(self: *Self, new: Pos) void {
                self.p = new;
            }

            pub fn distance(self: *Self, other: anytype) Pos.Dim {
                return Pos.distance(self.getPos(), other.getPos());
            }

            pub fn atXY(self: *Self, x: Pos.Dim, y: Pos.Dim) bool {
                return self.p.eql(Pos.init(x, y));
            }

            pub fn setXY(self: *Self, x: Pos.Dim, y: Pos.Dim) void {
                self.p = Pos.init(x, y);
            }
        };
    }
};

//
// Regions
//
pub const Region = struct {
    from: Pos,
    to: Pos,

    pub const Iterator = struct {
        r: *Region,
        x: Pos.Dim,
        y: Pos.Dim,

        pub fn next(self: *Region.Iterator) ?Pos {
            const oldx = self.x;
            const oldy = self.y;
            if (self.y > self.r.to.getY()) {
                return null;
            } else if (self.x >= self.r.to.getX()) { // next row
                self.y = self.y + 1;
                self.x = self.r.from.getX();
            } else {
                self.x = self.x + 1; // next column
            }
            return Pos.init(oldx, oldy);
        }
    };

    pub fn config(from: Pos, to: Pos) Region {
        if ((from.getX() < 0) or (from.getY() < 0) or (to.getX() < 0) or (to.getY() < 0)) {
            @panic("Region.config: Invalid position");
        }

        if ((from.getX() > to.getX()) or (from.getY() > to.getY())) {
            @panic("Region.config: Invalid region");
        }
        return .{ .from = from, .to = to };
    }

    pub fn isInside(self: *Region, p: Pos) bool {
        const from = self.getMin();
        const to = self.getMax();

        if ((p.getX() < from.getX()) or (p.getX() > to.getX()) or (p.getY() < from.getY()) or (p.getY() > to.getY())) {
            return false;
        }
        return true;
    }

    pub fn iterator(self: *Region) Region.Iterator {
        return .{ .r = self, .x = self.from.getX(), .y = self.from.getY() };
    }

    pub fn getMin(self: *Region) Pos {
        return self.from;
    }

    pub fn getMax(self: *Region) Pos {
        return self.to;
    }

    //
    // Region.Methods: mixin for clients of Region to lift up common functions
    //
    // use this as follows:  pub usingnamespace Region.Methods(@This());
    //
    pub fn Methods(comptime Self: type) type {

        // assumes a field 'r: Region' in whatever Self pulls this in

        return struct {
            pub fn getRegion(self: *Self) Region {
                return self.r;
            }

            pub fn getMin(self: *Self) Pos {
                return self.r.getMin();
            }

            pub fn getMinX(self: *Self) Pos.Dim {
                const min = self.r.getMin();
                return min.getX();
            }

            pub fn getMax(self: *Self) Pos {
                return self.r.getMax();
            }

            pub fn getMaxX(self: *Self) Pos.Dim {
                const max = self.r.getMax();
                return max.getX();
            }

            pub fn getMinY(self: *Self) Pos.Dim {
                const min = self.r.getMin();
                return min.getY();
            }

            pub fn getMaxY(self: *Self) Pos.Dim {
                const max = self.r.getMax();
                return max.getY();
            }

            pub fn isInside(self: *Self, at: Pos) bool {
                return self.r.isInside(at);
            }
        };
    }
};

//
// Common Error set
//
pub const ZrogueError = error{
    AlreadyInUse, // map
    ImplementationError, // FIXME Curses is annoying
    IndexOverflow, // map/grid
    OutOfBounds, // map/grid
};

//
// Results of the Thing.getAction() method, which drives what the game loop
// does next: keep going, plant a tombstone, declare victory, etc.
//

pub const ThingAction = struct {
    kind: Type,
    pos: Pos, // MoveAction (delta)

    pub const Type = enum {
        none,
        quit,
        ascend,
        descend,
        move, // Directional
        search,
        take, // Positional
        wait,
    };

    pub inline fn init(t: Type) ThingAction {
        return .{ .kind = t, .pos = Pos.init(0, 0) };
    }

    pub inline fn init_dir(t: Type, d: Pos.Direction) ThingAction {
        return .{ .kind = t, .pos = Pos.direct(d) };
    }

    pub inline fn init_pos(t: Type, p: Pos) ThingAction {
        return .{ .kind = t, .pos = p };
    }

    pub inline fn getPos(self: *ThingAction) Pos {
        return self.pos;
    }
};

//
// Unit Tests
//
const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "lock MapTile behavior" {
    for (0..@typeInfo(MapTile).@"enum".fields.len) |i| {
        const tile: MapTile = @enumFromInt(i);

        // Floors and unknown are not features.  Otherwise everything below
        // gold is.

        switch (tile) {
            .unknown, .floor => try expect(tile.isFeature() == false),
            else => {
                try expect(tile.isFeature() == (i < @intFromEnum(MapTile.gold)));
            },
        }

        // Walls and undiscovered secret doors are not passable.
        // .unknown is unclear
        const passable = (i != @intFromEnum(MapTile.wall));
        try expect(tile.isPassable() == passable);
    }
}

test "create a Pos and use its operations" {
    const a = Pos.init(5, 5);
    const b: Pos.Dim = 5;

    try expect(a.getY() == b);
    try expect(a.getX() == b);
    try expect(a.quant() == 25);
    try expect(a.isDim());
    try expect(a.eql(Pos.init(5, 5)));

    // Distance calculations

    try expect(Pos.distance(Pos.init(1, 1), Pos.init(2, 2)) == 1);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(3, 3)) == 2);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(0, 0)) == 1);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(1, 1)) == 0);
    try expect(Pos.distance(Pos.init(-1, -1), Pos.init(0, 0)) == 1);
}

test "Pos methods" {
    const Frotz = struct {
        p: Pos = undefined,

        pub usingnamespace Pos.Methods(@This());
    };

    var x = Frotz{ .p = Pos.init(0, 0) };

    x.setPos(Pos.init(25, -25));
    try expect(x.getX() == 25);
    try expect(x.getY() == -25);
    try expect(x.atXY(25, -25));
}

test "entity action" {
    var action = ThingAction.init(.quit);

    try expect(action.getPos().eql(Pos.init(0, 0)));

    action = ThingAction.init_dir(.move, .west);
    try expect(action.getPos().eql(Pos.init(-1, 0)));
}

// Invalid regions will panic

test "Region and region methods" {
    const min = Pos.init(2, 7);
    const max = Pos.init(9, 11);

    const Frotz = struct {
        r: Region = undefined,

        pub usingnamespace Region.Methods(@This());
    };

    var r = Region.config(min, max);
    try expect(min.eql(r.getMin()));
    try expect(max.eql(r.getMax()));

    var x = Frotz{ .r = Region.config(min, max) };
    try expect(x.getMinX() == 2);
    try expect(x.getMaxX() == 9);

    try expect(x.getMin().eql(min));
    try expect(x.getMax().eql(max));

    try expect(x.isInside(Pos.init(4, 10)));
    try expect(x.isInside(Pos.init(2, 7)));
    try expect(x.isInside(Pos.init(9, 11)));
    try expect(x.isInside(Pos.init(2, 11)));
    try expect(x.isInside(Pos.init(9, 7)));
    try expect(!x.isInside(Pos.init(0, 0)));
    try expect(!x.isInside(Pos.init(-10, -10)));
    try expect(!x.isInside(Pos.init(10, 0)));
    try expect(!x.isInside(Pos.init(0, 10)));
    try expect(!x.isInside(Pos.init(15, 21)));

    // We will call 1x1 valid for now. 1x1 at 0,0 is the uninitialized room
    _ = Region.config(Pos.init(0, 0), Pos.init(0, 0));
}

test "region iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);

    // Construct the iteration
    var r = Region.config(Pos.init(2, 7), Pos.init(9, 11));
    var i = r.iterator();
    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() <= ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() <= ARRAYDIM);
        a[f] = 1;
    }

    // Rigorously consider what should have been touched

    for (0..ARRAYDIM) |y| {
        for (0..ARRAYDIM) |x| {
            const val = a[x + y * ARRAYDIM];
            if ((x >= 2) and (x <= 9) and (y >= 7) and (y <= 11)) {
                try expect(val == 1);
            } else {
                try expect(val == 0);
            }
        }
    }
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var region_fields = genFields(Region);
pub var pos_fields = genFields(Pos);
pub var action_fields = genFields(ThingAction);

// EOF
