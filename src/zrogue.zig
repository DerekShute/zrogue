const std = @import("std");

//
// Common enums and errors
//
// This is the base dependency
//

//
// Constants relating to display conventions
//

pub const DISPLAY_MINX = 80;
pub const DISPLAY_MINY = 24;

pub const MESSAGE_ROW = 0; // At row zero
pub const STAT_ROW = DISPLAY_MINY; // TODO: technically, 'bottom'

pub const MAPSIZE_X = DISPLAY_MINX;
pub const MAPSIZE_Y = DISPLAY_MINY - 2; // Minus message and stat rows

pub const MESSAGE_MAXSIZE = DISPLAY_MINX;

//
// Input abstraction
//
pub const Command = enum {
    wait,
    quit,
    goWest, // 'up'/'down' confusing w/r/t stairs
    goEast,
    goNorth,
    goSouth,
    ascend,
    descend,
};

//
// Visible thing at map space
//
// TODO: union with monster types and objects?
//
pub const MapContents = enum {
    unknown,
    wall,
    floor,
    player,
};

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
    AlreadyInUse, // Curses
    DisplayTooSmall, // Curses
    ImplementationError, // Curses is annoying at least for now
    MapOverFlow,
    IndexOverflow,
};

//
// Results of the Thing.doAction() method, which drives what the game loop
// does next: keep going, plant a tombstone, declare victory, etc.
//
// TODO: within ThingAction
pub const ActionType = enum {
    NoAction,
    QuitAction,
    AscendAction,
    BumpAction, // Directional
    DescendAction,
};

pub const ThingAction = struct {
    type: ActionType,
    pos: Pos, // BumpAction (delta)

    pub inline fn init(t: ActionType) ThingAction {
        return .{ .type = t, .pos = Pos.init(0, 0) };
    }

    pub inline fn init_pos(t: ActionType, p: Pos) ThingAction {
        return .{ .type = t, .pos = p };
    }
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
