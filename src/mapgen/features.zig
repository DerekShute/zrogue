//!
//! Map features
//!

const std = @import("std");
const Feature = @import("../Feature.zig");
const Pos = @import("../zrogue.zig").Pos;
const Map = @import("../map.zig").Map;
const Thing = @import("../thing.zig").Thing;

//
// Secret Door
//

fn findSecretDoor(s: *Feature, m: *Map) bool {
    // TODO: chance to succeed
    m.setTile(s.getPos(), .door) catch unreachable; // bad Pos of feature?
    m.removeFeature(s) catch unreachable; // bad Pos?
    return true; // Found
}

const secretdoor_vtable: Feature.VTable = .{
    .find = findSecretDoor,
    .enter = null,
};

pub fn configSecretDoor(p: Pos) Feature {
    return .{
        .p = p,
        .vtable = &secretdoor_vtable,
    };
}

//
// Trap
//

fn findTrap(s: *Feature, m: *Map) bool {
    // TODO: chance to succeed
    m.setTile(s.getPos(), .trap) catch unreachable; // bad Pos of feature?
    return true; // Found
}

fn enterTrap(s: *Feature, m: *Map, t: *Thing) void {
    // TODO: chance to avoid
    m.setTile(s.getPos(), .trap) catch unreachable; // bad Pos of feature?
    t.addMessage("You step on a trap!");
    // TODO: increment moves or something
}

const trap_vtable: Feature.VTable = .{
    .find = findTrap,
    .enter = enterTrap,
};

pub fn configTrap(p: Pos) Feature {
    // TODO: kind of trap
    return .{
        .p = p,
        .vtable = &trap_vtable,
    };
}

//
// Unit tests
//

const expect = std.testing.expect;

test "Place a secret door" {
    var m = try Map.init(std.testing.allocator, 25, 25, 1, 1);
    defer m.deinit();

    const p = Pos.init(10, 10);
    try m.addFeature(configSecretDoor(p));

    // Secret doors are walls until discovered

    try expect(try m.getFloorTile(p) == .wall);
    var f = try m.getFeature(p);
    try expect(f != null);
    const found = f.?.find(m);
    try expect(found);
    try expect(try m.getFloorTile(p) == .door);
}

test "Place a trap" {
    var m = try Map.init(std.testing.allocator, 25, 25, 1, 1);
    defer m.deinit();

    const p = Pos.init(10, 10);
    try m.setTile(p, .floor); // Precondition
    try m.addFeature(configTrap(p));

    // Traps appear as floors until discovered

    try expect(try m.getFloorTile(p) == .floor);
    var f = try m.getFeature(p);
    try expect(f != null);
    const found = f.?.find(m);
    try expect(found);
    try expect(try m.getFloorTile(p) == .trap);
    // TODO: step on one
}

// EOF
