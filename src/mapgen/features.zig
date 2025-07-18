//!
//! Map features
//!

const std = @import("std");
const Feature = @import("../Feature.zig");
const Pos = @import("../zrogue.zig").Pos;
const Map = @import("../map.zig").Map;

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

// TODO: step on

const trap_vtable: Feature.VTable = .{ .find = findTrap };

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

    // Secret doors are floors until discovered

    try expect(try m.getFloorTile(p) == .floor);
    var f = try m.getFeature(p);
    try expect(f != null);
    const found = f.?.find(m);
    try expect(found);
    try expect(try m.getFloorTile(p) == .trap);
}

// EOF
