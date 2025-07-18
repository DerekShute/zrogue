//!
//! map special features: hidden doors, traps, chests(?), summoners
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const Map = @import("map.zig").Map;

const Self = @This();

//
// Vector Table
//

pub const VTable = struct {
    find: *const fn (self: *Self, map: *Map) bool,
    // Take, etc.
};

//
// Members
//

p: zrogue.Pos = undefined,
vtable: ?*const VTable = null,

//
// Methods
//

pub fn find(self: *Self, map: *Map) bool {

    // Entity searches the map location; this is the consequence of
    // finding this feature.  Returns 'false' if not found, 'true' otherwise

    if (self.vtable) |v| {
        return v.find(self, map);
    }
    return false;
}

//
// Import Pos functions
//

pub usingnamespace zrogue.Pos.Methods(@This());

//
// Unit test
//

const expect = std.testing.expect;

fn testFind(self: *Self, map: *Map) bool {
    _ = map;
    _ = self;
    return true;
}

const test_vtable: VTable = .{
    .find = testFind,
};

test "Feature vtable execution" {
    const m = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer m.deinit();
    var f = Self{ .p = zrogue.Pos.init(1, 1), .vtable = &test_vtable };

    try expect(find(&f, m) == true);
}

test "Feature vtable fallthrough" {
    const m = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer m.deinit();
    var f = Self{ .p = zrogue.Pos.init(1, 1), .vtable = null };

    try expect(find(&f, m) == false);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var feature_fields = genFields(Self);

// EOF
