//!
//! Common enums and errors
//!
//! This is the base dependency and its existence is a relic of C mentality
//!

const std = @import("std");
pub const Pos = @import("utils/Pos.zig");

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
