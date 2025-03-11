const std = @import("std");
const zrogue = @import("zrogue.zig");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const Room = @import("map.zig").Room;
const Thing = @import("thing.zig").Thing;

const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;

//
// Level generation from the top
//

// Encapsulate arguments
pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
};

//
// Fixed things at fixed locations for deterministic behavior
//
pub fn createTestLevel(config: LevelConfig) !*Map {
    var map = try Map.init(config.allocator, config.xSize, config.ySize, 3, 2);
    errdefer map.deinit();

    var room = try Room.config(Pos.init(2, 2), Pos.init(9, 9));
    room.setDark();
    try map.addRoom(room);

    try map.addRoom(try Room.config(Pos.init(27, 5), Pos.init(35, 10)));
    try map.dig(Pos.init(9, 5), Pos.init(27, 8));

    try map.addRoom(try Room.config(Pos.init(4, 12), Pos.init(20, 19)));
    try map.dig(Pos.init(4, 9), Pos.init(18, 12));

    try map.addItem(Item.config(10, 16, .gold));

    if (config.player) |p| {
        try map.setMonster(p, 6, 6);
    }

    return map;
}

// TODO: destructor

pub const createLevel = createTestLevel;

//
// Randomly-generated level
//

// TODO

// Unit tests

test "use test level" {
    // TODO need mock Thing
    const allocator = std.testing.allocator;
    const config = LevelConfig{
        .allocator = allocator,
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
    };

    const map = try createTestLevel(config);
    defer map.deinit();
}

// EOF
