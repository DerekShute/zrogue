//!
//! map special features: hidden doors, traps, chests(?), summoners
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const Map = @import("map.zig").Map;

const Self = @This();

pub const VTable = struct {
    find: *const fn (self: *Self, map: *Map) bool,
    // Take, etc.
};

pub const Config = struct {
    pos: zrogue.Pos,
    vtable: ?*VTable,
};

p: zrogue.Pos = undefined,
vtable: ?*const VTable = null,

pub fn find(self: *Self, map: *Map) bool {
    if (self.vtable) |v| {
        return v.find(self, map);
    }
    return false;
}

// Import Pos functions

pub usingnamespace zrogue.Pos.Methods(@This());

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var feature_fields = genFields(Self);

// EOF
