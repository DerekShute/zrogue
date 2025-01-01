const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const ZrogueError = @import("zrogue.zig").ZrogueError;

// ===================
// Structure for monsters, player, and objects

const ActionHandler = *const fn (self: *Thing) ZrogueError!void;

pub const Thing = struct {
    // TODO: parent and parent type and whether this turns into an interface
    xy: [2]u16 = .{ 0, 0 },
    ch: u8 = ' ',
    input: InputProvider = undefined,
    display: DisplayProvider = undefined,
    doaction: ActionHandler = undefined,

    pub fn config(xy: [2]u16, ch: u8, input: InputProvider, display: DisplayProvider, action: ActionHandler) Thing {
        return Thing{
            .xy = xy,
            .ch = ch,
            .input = input,
            .display = display,
            .doaction = action,
        };
    }

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

    pub fn doAction(self: *Thing) ZrogueError!void {
        try self.doaction(self); // Why no synctactic sugar here?
    }

    // TODO: setX, setY, moveRelative, getX, getY, etc

};

//
// Full API testing broken out in game.zig because config() is getting complex
//
test "create a thing" {
    const TestStruct = struct {
        // Want to prove that we get all the way into the action callback and
        // don't want to pollute the module with "x"
        var x: usize = 0;

        fn action(self: *Thing) !void {
            _ = self;
            x = 1; // Side effect
        }
    };

    var thing = Thing{ .xy = .{ 0, 0 }, .ch = '@', .doaction = TestStruct.action };
    try std.testing.expect(thing.atPos(.{ 0, 0 }));
    thing.setPos(.{ 10, 10 });
    try std.testing.expect(thing.atPos(.{ 10, 10 }));
    try std.testing.expect(thing.getChar() == '@');

    try thing.doAction();
    try std.testing.expect(TestStruct.x == 1);
}
// EOF
