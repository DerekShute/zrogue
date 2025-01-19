const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Map = @import("level.zig").Map;
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;

// ===================
// Structure for monsters, player, and objects

const ActionHandler = *const fn (self: *Thing, map: *Map) ZrogueError!ThingAction;

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

    pub fn doAction(self: *Thing, map: *Map) ZrogueError!ThingAction {
        return try self.doaction(self, map); // Why no synctactic sugar here?
    }

    // TODO: setX, setY, moveRelative, getX, getY, getXY, etc

};

// EOF
