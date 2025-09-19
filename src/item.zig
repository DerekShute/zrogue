//!
//! Items (Gold)
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;

// ===================
//
// Objects, gear, etc.
//
pub const Item = struct {
    p: Pos = undefined,
    tile: MapTile = .unknown,
    // TODO Future: note if in player inventory
    // TODO Future: 'known' : identified to know # of charges / bonuses

    pub fn config(x: Pos.Dim, y: Pos.Dim, tile: MapTile) Item {
        return .{
            .p = Pos.init(x, y),
            .tile = tile,
        };
    }

    pub fn getTile(self: *Item) MapTile {
        return self.tile;
    }

    // Pos not-mixin methods

    pub fn getX(self: @This()) Pos.Dim {
        return self.p.getX();
    }

    pub fn getY(self: @This()) Pos.Dim {
        return self.p.getY();
    }

    pub fn setPos(self: *@This(), new: Pos) void {
        self.p = new;
    }

    pub fn atXY(self: *@This(), x: Pos.Dim, y: Pos.Dim) bool {
        return self.p.eql(Pos.init(x, y));
    }
};

//
// Unit Tests
//

test "create an item" {
    var it = Item.config(0, 0, .gold);
    const p = Pos.init(0, 0);

    try expect(p.eql(it.getPos()));
    try expect(it.getTile() == .gold);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub const fields = genFields(Item);

// EOF
