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

// Original Rogue uses a 3x3 grid but that feels cramped at least right now

pub const ROOMS_X = 3;
pub const ROOMS_Y = 2;

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
    takeItem,
};

//
// Visible thing at map space
//
// TODO: union with monster types and objects?
//
pub const MapTile = enum {
    unknown,
    wall,
    floor,
    door,
    gold,
    player,

    pub fn feature(self: MapTile) bool {
        return ((self == .wall) or (self == .door)); // TODO stairs
    }

    pub fn passable(self: MapTile) bool {
        // Everything not solid is passable
        // TODO, is < floor (what about monsters, player?)
        return ((self != .wall) and (self != .unknown));
    }
};

//
// Map coordinates and width/height and directional deltas
//
pub const Pos = struct {
    pub const Dim = i16;

    // TODO: directionals

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

    // Chebyshev distance
    pub inline fn distance(pos1: Pos, pos2: Pos) Dim {
        const maxx = @abs(pos1.getX() - pos2.getX());
        const maxy = @abs(pos1.getY() - pos2.getY());
        return if (maxx > maxy) @intCast(maxx) else @intCast(maxy);
    }
};

//
// Regions
//
pub const Region = struct {
    from: Pos,
    to: Pos,

    pub const Iterator = struct {
        r: *Region,
        x: Pos.Dim,
        y: Pos.Dim,

        pub fn next(self: *Region.Iterator) ?Pos {
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

    pub fn config(from: Pos, to: Pos) !Region {
        if ((from.getX() < 0) or (from.getY() < 0) or (to.getX() < 0) or (to.getY() < 0)) {
            return ZrogueError.OutOfBounds;
        }

        if ((from.getX() > to.getX()) or (from.getY() > to.getY())) {
            return ZrogueError.OutOfBounds;
        }
        return .{ .from = from, .to = to };
    }

    pub fn iterator(self: *Region) Region.Iterator {
        return .{ .r = self, .x = self.from.getX(), .y = self.from.getY() };
    }

    pub fn getMin(self: *Region) Pos {
        return self.from;
    }

    pub fn getMax(self: *Region) Pos {
        return self.to;
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
    IndexOverflow,
    MapOverFlow,
    OutOfBounds,
};

//
// Results of the Thing.getAction() method, which drives what the game loop
// does next: keep going, plant a tombstone, declare victory, etc.
//
// TODO: within ThingAction
pub const ActionType = enum {
    NoAction,
    QuitAction,
    AscendAction,
    DescendAction,
    MoveAction, // Directional
    TakeAction, // Positional
};

pub const ThingAction = struct {
    kind: ActionType,
    pos: Pos, // MoveAction (delta)

    pub inline fn init(t: ActionType) ThingAction {
        return .{ .kind = t, .pos = Pos.init(0, 0) };
    }

    pub inline fn init_pos(t: ActionType, p: Pos) ThingAction {
        return .{ .kind = t, .pos = p };
    }

    pub inline fn getPos(self: *ThingAction) Pos {
        return self.pos;
    }
};

//
// Unit Tests
//

test "create a Pos and use its operations" {
    const a = Pos.init(5, 5);
    const b: Pos.Dim = 5;
    const expect = std.testing.expect;

    try expect(a.getY() == b);
    try expect(a.getX() == b);
    try expect(a.quant() == 25);
    try expect(a.isDim());
    try expect(a.eql(Pos.init(5, 5)));

    // Distance calculations

    try expect(Pos.distance(Pos.init(1, 1), Pos.init(2, 2)) == 1);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(3, 3)) == 2);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(0, 0)) == 1);
    try expect(Pos.distance(Pos.init(1, 1), Pos.init(1, 1)) == 0);
    try expect(Pos.distance(Pos.init(-1, -1), Pos.init(0, 0)) == 1);
}

test "entity action" {
    var action = ThingAction.init(ActionType.QuitAction);
    const expect = std.testing.expect;

    try expect(action.getPos().eql(Pos.init(0, 0)));

    action = ThingAction.init_pos(ActionType.MoveAction, Pos.init(-1, 0));
    try expect(action.getPos().eql(Pos.init(-1, 0)));
}

test "invalid regions" {
    const expectError = std.testing.expectError;

    try expectError(ZrogueError.OutOfBounds, Region.config(Pos.init(5, 5), Pos.init(4, 4)));
    try expectError(ZrogueError.OutOfBounds, Region.config(Pos.init(-1, 4), Pos.init(5, 5)));
    try expectError(ZrogueError.OutOfBounds, Region.config(Pos.init(4, -1), Pos.init(5, 5)));
    try expectError(ZrogueError.OutOfBounds, Region.config(Pos.init(4, 4), Pos.init(-1, 5)));
    try expectError(ZrogueError.OutOfBounds, Region.config(Pos.init(4, 4), Pos.init(5, -1)));
}

test "region" {
    const expect = std.testing.expect;
    const min = Pos.init(2, 7);
    const max = Pos.init(9, 11);

    var r = try Region.config(min, max);
    try expect(min.eql(r.getMin()));
    try expect(max.eql(r.getMax()));

    // We will call 1x1 valid for now. 1x1 at 0,0 is the uninitialized room
    _ = try Region.config(Pos.init(0, 0), Pos.init(0, 0));
}

test "region iterator" {
    const ARRAYDIM = 14;
    var a = [_]u8{0} ** (ARRAYDIM * ARRAYDIM);
    const expect = std.testing.expect;

    // Construct the iteration
    var r = try Region.config(Pos.init(2, 7), Pos.init(9, 11));
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

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var region_fields = genFields(Region);
pub var pos_fields = genFields(Pos);
pub var action_fields = genFields(ThingAction);

// EOF
