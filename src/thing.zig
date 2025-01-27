const std = @import("std");
const DisplayProvider = @import("display.zig").DisplayProvider;
const InputProvider = @import("input.zig").InputProvider;
const Map = @import("level.zig").Map;
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const MessageLog = @import("message_log.zig").MessageLog;

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
    log: ?*MessageLog = null,

    // msglog: monsters don't have it
    pub fn config(x: Pos.Dim, y: Pos.Dim, ch: u8, input: InputProvider, display: DisplayProvider, action: ActionHandler, msglog: ?*MessageLog) Thing {
        return Thing{
            .xy = Pos.init(x, y),
            .ch = ch,
            .input = input,
            .display = display,
            .doaction = action,
            .log = msglog,
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

    //
    // Log messages to the thing (if something was set)
    //

    pub fn addMessage(self: *Thing, msg: []const u8) void {
        if (self.log) |log| {
            log.add(msg);
        }
    }

    pub fn getMessage(self: *Thing) []u8 {
        if (self.log) |log| {
            return log.get();
        }
        return ""; // TODO sure why not
    }

    pub fn clearMessage(self: *Thing) void {
        if (self.log) |log| {
            return log.clear();
        }
    }

    // TODO: setX, setY, moveRelative, getX, getY, getXY, etc

};

// EOF
