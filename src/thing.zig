const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;

const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;

// ===================
// Structure for monsters, player, and objects

const ActionHandler = *const fn (self: *Thing) ZrogueError!ThingAction;

pub const Thing = struct {
    // TODO: parent and parent type and whether this turns into an interface
    // TODO: timer, action queue
    xy: Pos = Pos.init(-1, -1),
    ch: u8 = ' ',
    input: InputProvider = undefined,
    display: DisplayProvider = undefined,
    doaction: ActionHandler = undefined,

    pub fn config(x: Pos.Dim, y: Pos.Dim, ch: u8, input: InputProvider, display: DisplayProvider, action: ActionHandler) Thing {
        return Thing{
            .xy = Pos.init(x, y),
            .ch = ch,
            .input = input,
            .display = display,
            .doaction = action,
        };
    }

    pub fn getPos(self: *Thing) Pos {
        return self.xy;
    }

    pub fn setXY(self: *Thing, x: Pos.Dim, y: Pos.Dim) void {
        self.xy = Pos.init(x, y);
    }

    pub fn getChar(self: *Thing) u8 {
        return self.ch;
    }

    pub fn atXY(self: *Thing, x: Pos.Dim, y: Pos.Dim) bool {
        return self.xy.eql(Pos.init(x, y));
    }

    pub fn doAction(self: *Thing) ZrogueError!ThingAction {
        return try self.doaction(self); // Why no synctactic sugar here?
    }

    // TODO: setX, setY, moveRelative, getX, getY, getXY, etc

};

//
// Full API testing broken out in game.zig because config() is getting complex
//
test "create a thing" {
    const TestStruct = struct {
        // Want to prove that we get all the way into the action callback and
        // don't want to pollute the module with "x"
        var x: usize = 0;

        fn action(self: *Thing) !ThingAction {
            _ = self;
            x = 1; // Side effect
            return ThingAction.init(ActionType.NoAction);
        }
    };

    var thing = Thing{ .xy = Pos.init(0, 0), .ch = '@', .doaction = TestStruct.action };
    try std.testing.expect(thing.atXY(0, 0));
    thing.setXY(10, 10);
    try std.testing.expect(thing.atXY(10, 10));
    try std.testing.expect(thing.getChar() == '@');

    const action = try thing.doAction();
    try std.testing.expect(action.type == ActionType.NoAction);
    try std.testing.expect(TestStruct.x == 1);
}
// EOF
