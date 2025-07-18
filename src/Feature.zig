//!
//! map special features: hidden doors, traps, chests(?), summoners
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const Map = @import("map.zig").Map;
const Thing = @import("thing.zig").Thing;

const Self = @This();

//
// Vector Table
//

pub const VTable = struct {
    find: *const fn (self: *Self, map: *Map) bool,
    enter: ?*const fn (self: *Self, map: *Map, thing: *Thing) void,
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

pub fn enter(self: *Self, map: *Map, thing: *Thing) void {

    // Entity steps into the place where this is

    if (self.vtable) |v| {
        if (v.enter) |cb| {
            cb(self, map, thing);
        }
    }
}

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

fn testEnter(self: *Self, map: *Map, thing: *Thing) void {
    _ = self;
    _ = map;
    _ = thing;
}

const test_vtable: VTable = .{
    .find = testFind,
    .enter = testEnter,
};

test "Feature vtable execution" {
    const m = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer m.deinit();
    var f = Self{ .p = zrogue.Pos.init(1, 1), .vtable = &test_vtable };
    var t = Thing{};

    try expect(find(&f, m) == true);
    enter(&f, m, &t);
}

test "Feature vtable fallthrough" {
    const m = try Map.init(std.testing.allocator, 50, 50, 1, 1);
    defer m.deinit();
    var f = Self{ .p = zrogue.Pos.init(1, 1), .vtable = null };
    var t = Thing{};

    try expect(find(&f, m) == false);
    enter(&f, m, &t);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var feature_fields = genFields(Self);

// EOF
