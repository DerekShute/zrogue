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
const Item = struct {
    allocator: std.mem.Allocator,
    xy: Pos = Pos.init(-1, -1),
    tile: MapTile = .unknown,
    // TODO: note if in player inventory
    // TODO: 'known' : identified to know # of charges / bonuses

    pub fn init(allocator: std.mem.Allocator, x: Pos.Dim, y: Pos.Dim, tile: MapTile) !*Item {
        const item: *Item = try allocator.create(Item);
        errdefer allocator.destroy(item);

        item.allocator = allocator;
        item.xy = Pos.init(x, y);
        item.tile = tile;

        return item;
    }

    pub fn deinit(self: *Item) void {
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

//
// Unit Tests
//

test "create an item" {
    var item = try Item.init(std.testing.allocator, 0, 0, .gold);
    defer item.deinit();
}

test "fail to create an item" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });

    const item = Item.init(failing.allocator(), 0, 0, .gold);
    try expectError(error.OutOfMemory, item);
}

//
// Visualization
//

const genFields = @import("visual.zig").genFields;
pub const fields = genFields(Item);

// EOF
