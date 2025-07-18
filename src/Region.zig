//!
//! Region
//!

const std = @import("std");
const Pos = @import("zrogue.zig").Pos;

const Self = @This();

//
// Members
//

from: Pos = undefined,
to: Pos = undefined,

//
// Constructor
//

pub fn config(from: Pos, to: Pos) Self {
    if ((from.getX() < 0) or (from.getY() < 0) or (to.getX() < 0) or (to.getY() < 0)) {
        @panic("Region.config: Invalid position");
    }

    if ((from.getX() > to.getX()) or (from.getY() > to.getY())) {
        @panic("Region.config: Invalid region");
    }
    return .{ .from = from, .to = to };
}

pub fn configRadius(center: Pos, radius: Pos.Dim) Self {
    // Square centered on 'center', radius 'radius'
    const min = Pos.init(center.getX() - radius, center.getY() - radius);
    const max = Pos.init(center.getX() + radius, center.getY() + radius);

    return config(min, max);
}

//
// Iterator
//

pub const Iterator = struct {
    r: *Self,
    x: Pos.Dim,
    y: Pos.Dim,

    pub fn next(self: *Iterator) ?Pos {
        const oldx = self.x;
        const oldy = self.y;
        if (self.y > self.r.to.getY()) {
            return null;
        } else if (self.x >= self.r.to.getX()) { // next row
            self.y = self.y + 1;
            self.x = self.r.from.getX();
        } else {
            self.x = self.x + 1; // next column
        }
        return Pos.init(oldx, oldy);
    }
};

pub fn iterator(self: *Self) Iterator {
    return .{ .r = self, .x = self.from.getX(), .y = self.from.getY() };
}

//
// Methods
//

pub fn getMin(self: *Self) Pos {
    return self.from;
}

pub fn getMax(self: *Self) Pos {
    return self.to;
}

pub fn isInside(self: *Self, p: Pos) bool {
    const from = self.getMin();
    const to = self.getMax();

    if ((p.getX() < from.getX()) or (p.getX() > to.getX()) or (p.getY() < from.getY()) or (p.getY() > to.getY())) {
        return false;
    }
    return true;
}

//
// Mixin Methods : mixin for clients of Region to lift up common functions
//
// use this as follows:  pub usingnamespace Region.Methods(@This());
//

pub fn Methods(comptime MSelf: type) type {
    if (@FieldType(MSelf, "r") != Self) {
        @compileError("Expected a field r:Region in " ++ @typeName(MSelf));
    }

    return struct {
        pub fn getRegion(self: *MSelf) Self {
            return self.r;
        }

        pub fn getMin(self: *MSelf) Pos {
            return self.r.getMin();
        }

        pub fn getMinX(self: *MSelf) Pos.Dim {
            const min = self.r.getMin();
            return min.getX();
        }

        pub fn getMax(self: *MSelf) Pos {
            return self.r.getMax();
        }

        pub fn getMaxX(self: *MSelf) Pos.Dim {
            const max = self.r.getMax();
            return max.getX();
        }

        pub fn getMinY(self: *MSelf) Pos.Dim {
            const min = self.r.getMin();
            return min.getY();
        }

        pub fn getMaxY(self: *MSelf) Pos.Dim {
            const max = self.r.getMax();
            return max.getY();
        }

        pub fn isInside(self: *MSelf, at: Pos) bool {
            return self.r.isInside(at);
        }
    };
}

//
// Unit tests
//
// Invalid regions will panic
//

const expect = std.testing.expect;

test "Region and Region methods" {
    const min = Pos.init(2, 7);
    const max = Pos.init(9, 11);

    const Frotz = struct {
        r: Self = undefined,

        pub usingnamespace Methods(@This());
    };

    var r = Self.config(min, max);
    try expect(min.eql(r.getMin()));
    try expect(max.eql(r.getMax()));

    var x = Frotz{ .r = Self.config(min, max) };
    try expect(x.getMinX() == 2);
    try expect(x.getMaxX() == 9);

    try expect(x.getMin().eql(min));
    try expect(x.getMax().eql(max));

    try expect(x.isInside(Pos.init(4, 10)));
    try expect(x.isInside(Pos.init(2, 7)));
    try expect(x.isInside(Pos.init(9, 11)));
    try expect(x.isInside(Pos.init(2, 11)));
    try expect(x.isInside(Pos.init(9, 7)));
    try expect(!x.isInside(Pos.init(0, 0)));
    try expect(!x.isInside(Pos.init(-10, -10)));
    try expect(!x.isInside(Pos.init(10, 0)));
    try expect(!x.isInside(Pos.init(0, 10)));
    try expect(!x.isInside(Pos.init(15, 21)));

    // We will call 1x1 valid for now. 1x1 at 0,0 is the uninitialized room
    _ = Self.config(Pos.init(0, 0), Pos.init(0, 0));
}

test "Region iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);

    // Construct the iteration
    var r = Self.config(Pos.init(2, 7), Pos.init(9, 11));
    var i = r.iterator();
    while (i.next()) |pos| {
        const f: usize = @intCast(pos.getX() + pos.getY() * ARRAYDIM);
        try expect(pos.getX() >= 0);
        try expect(pos.getX() <= ARRAYDIM);
        try expect(pos.getY() >= 0);
        try expect(pos.getY() <= ARRAYDIM);
        a[f] = 1;
    }

    // Rigorously consider what should have been touched

    for (0..ARRAYDIM) |y| {
        for (0..ARRAYDIM) |x| {
            const val = a[x + y * ARRAYDIM];
            if ((x >= 2) and (x <= 9) and (y >= 7) and (y <= 11)) {
                try expect(val == 1);
            } else {
                try expect(val == 0);
            }
        }
    }
}

test "Region radius constructor" {
    var r = Self.configRadius(Pos.init(10, 15), 2);

    try expect(r.getMin().getX() == 8);
    try expect(r.getMin().getY() == 13);
    try expect(r.getMax().getX() == 12);
    try expect(r.getMax().getY() == 17);
}

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var region_fields = genFields(Self);

// EOF
