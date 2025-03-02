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
    xy: Pos = Pos.init(-1, -1),
    tile: MapTile = .unknown,
    // TODO: note if in player inventory
    // TODO: 'known' : identified to know # of charges / bonuses

    pub fn config(x: Pos.Dim, y: Pos.Dim, tile: MapTile) Item {
        return .{
            .xy = Pos.init(x, y),
            .tile = tile,
        };
    }

    pub fn getPos(self: *Item) Pos {
        return self.xy;
    }

    pub fn getTile(self: *Item) MapTile {
        return self.tile;
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

const genFields = @import("visual.zig").genFields;
pub const fields = genFields(Item);

// EOF
