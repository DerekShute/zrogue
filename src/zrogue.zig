const std = @import("std");

//
// Common enums and errors
//
// This is the base dependency
//

//
// Map coordinates and width/height and directional deltas
//
pub const Pos = struct {
    pub const Dim = i16;

    xy: [2]Dim = .{ -1, -1 },

    pub inline fn init(x: Dim, y: Dim) Pos {
        return .{ .xy = .{ x, y } };
    }

    pub inline fn quant(self: Pos) usize {
        return @intCast(self.xy[0] * self.xy[1]);
    }

    pub inline fn getX(self: Pos) Dim {
        return self.xy[0];
    }

    pub inline fn getY(self: Pos) Dim {
        return self.xy[1];
    }

    pub inline fn isDim(self: Pos) bool {
        return ((self.getX() >= 0) and (self.getY() >= 0));
    }

    pub inline fn eql(self: Pos, other: Pos) bool {
        return ((self.getX() == other.getX()) and (self.getY() == other.getY()));
    }
};

//
// Common Error set
//
pub const ZrogueError = error{
    NotInitialized,
    ImplementationError, // Curses is annoying at least for now
};

//
// Results of the Thing.doAction() method, which drives what the game loop
// does next: keep going, plant a tombstone, declare victory, etc.
//
pub const ActionEvent = enum {
    NoEvent,
    QuittingGame,
};

//
// UNIT TESTS
//

test "create a Pos and use its operations" {
    const a = Pos.init(5, 5);
    const b: Pos.Dim = 5;

    try std.testing.expect(a.getY() == b);
    try std.testing.expect(a.getX() == b);
    try std.testing.expect(a.quant() == 25);
    try std.testing.expect(a.isDim());
    try std.testing.expect(a.eql(Pos.init(5, 5)));
}

// EOF
