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
// REFACTOR: is this an input.zig thing?
// REFACTOR: Partially duplicates ThingAction.type
pub const Command = enum {
    wait,
    quit,
    go_north, // 'up'/'down' confusing w/r/t stairs
    go_east,
    go_south,
    go_west,
    ascend,
    descend,
    help,
    take_item,
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
    trap,
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
        if (@FieldType(Self, "p") != Pos) {
            @compileError("Expected a field p:Pos in " ++ @typeName(Self));
        }

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

pub const Region = @import("Region.zig");

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

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var pos_fields = genFields(Pos);
pub var action_fields = genFields(ThingAction);

// EOF
