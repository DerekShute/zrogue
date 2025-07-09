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

pos: zrogue.Pos = undefined,
vtable: ?*const VTable = null,

// TODO: Pos features
pub fn getPos(self: *Self) zrogue.Pos {
    return self.pos;
}

pub fn find(self: *Self, map: *Map) bool {
    if (self.vtable) |v| {
        return v.find(self, map);
    }
    return false;
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var feature_fields = genFields(Self);

// EOF
