const std = @import("std");

// ===================
// Structure for monsters, player, and objects

pub const Thing = struct {
    // TODO: parent and parent type and whether this turns into an interface
    xy: [2]u16 = .{ 0, 0 },
    ch: u8 = ' ',

    pub fn getPos(self: *Thing) [2]u16 {
        return self.xy;
    }

    pub fn setPos(self: *Thing, xy: [2]u16) void {
        self.xy = xy;
    }

    pub fn getChar(self: *Thing) u8 {
        return self.ch;
    }

    pub fn atPos(self: *Thing, pos: [2]u16) bool {
        return std.mem.eql(u16, &self.xy, &pos);
    }

    // TODO: setX, setY, moveRelative, getX, getY, etc
};

test "create a thing" {
    var thing = Thing{ .xy = .{ 0, 0 }, .ch = '@' };
    try std.testing.expect(thing.atPos(.{ 0, 0 }));
    thing.setPos(.{ 10, 10 });
    try std.testing.expect(thing.atPos(.{ 10, 10 }));
    try std.testing.expect(thing.getChar() == '@');
}
// EOF
