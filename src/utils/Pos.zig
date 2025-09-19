//!
//! Positions
//!
//! And mixin-type abstractions of positions

const std = @import("std");

//
// Internals
//

const Self = @This();

pub const Dim = i16;

pub const Direction = enum {
    north,
    east,
    south,
    west,
};

//
// Fields
//

xy: [2]Dim = .{ -1, -1 },

//
// Methods
//

pub inline fn init(x: Dim, y: Dim) Self {
    return .{ .xy = .{ x, y } };
}

pub inline fn direct(d: Direction) Self {
    return switch (d) {
        .north => init(0, -1),
        .east => init(1, 0),
        .south => init(0, 1),
        .west => init(-1, 0),
    };
}

pub inline fn quant(self: Self) usize {
    return @intCast(self.xy[0] * self.xy[1]);
}

pub inline fn getX(self: Self) Dim {
    return self.xy[0];
}

pub inline fn getY(self: Self) Dim {
    return self.xy[1];
}

pub inline fn isDim(self: Self) bool {
    return ((self.getX() >= 0) and (self.getY() >= 0));
}

pub inline fn eql(p1: anytype, p2: anytype) bool {
    return ((p1.getX() == p2.getX()) and (p1.getY() == p2.getY()));
}

// Implication is that one of these is a delta
pub inline fn add(p1: anytype, p2: anytype) Self {
    return init(p1.getX() + p2.getX(), p1.getY() + p2.getY());
}

// Chebyshev distance
pub inline fn distance(p1: anytype, p2: anytype) Dim {
    const maxx = @abs(p1.getX() - p2.getX());
    const maxy = @abs(p1.getY() - p2.getY());
    return if (maxx > maxy) @intCast(maxx) else @intCast(maxy);
}

//
// Unit Tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "create and use operations" {
    const a = init(5, 5);
    const b: Dim = 5;

    try expect(a.getY() == b);
    try expect(a.getX() == b);
    try expect(a.quant() == 25);
    try expect(a.isDim());
    try expect(a.eql(init(5, 5)));

    // Distance calculations

    try expect(distance(init(1, 1), init(2, 2)) == 1);
    try expect(distance(init(1, 1), init(3, 3)) == 2);
    try expect(distance(init(1, 1), init(0, 0)) == 1);
    try expect(distance(init(1, 1), init(1, 1)) == 0);
    try expect(distance(init(-1, -1), init(0, 0)) == 1);

    // Addition

    var y = add(init(1, -1), init(5, 5));
    try expect(y.getX() == 6);
    try expect(y.getY() == 4);
}

test "methods and mixins implementation" {
    const Frotz = struct {
        p: Self = undefined,

        // These are the minimums necessary for the anytype routines, above

        pub fn getX(self: @This()) Dim {
            return self.p.getX();
        }

        pub fn getY(self: @This()) Dim {
            return self.p.getY();
        }

        pub fn setPos(self: *@This(), new: Self) void {
            self.p = new;
        }

        pub fn atXY(self: *@This(), x: Dim, y: Dim) bool {
            return self.p.eql(init(x, y));
        }
    };

    var x = Frotz{ .p = init(0, 0) };

    x.setPos(init(25, -25));
    try expect(x.getX() == 25);
    try expect(x.getY() == -25);
    try expect(x.atXY(25, -25));
    try expect(distance(x, init(0, 0)) == 25);

    var y = add(x, init(1, -1));
    try expect(y.getX() == 26);
    try expect(y.getY() == -26);

    try expect(eql(init(0, 0), y) == false);
}

// EOF
