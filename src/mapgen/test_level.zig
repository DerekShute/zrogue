const std = @import("std");
const mapgen = @import("mapgen.zig");
const zrogue = @import("../zrogue.zig");

const Item = @import("../item.zig").Item;
const LevelConfig = mapgen.LevelConfig;
const Map = @import("../map.zig").Map;
const Pos = zrogue.Pos;
const Room = @import("../map.zig").Room;
const Thing = @import("../thing.zig").Thing;

//
// Fixed things at fixed locations for deterministic behavior
//
pub fn createTestLevel(config: LevelConfig) !*Map {
    var map = try Map.init(config.allocator, config.xSize, config.ySize, 3, 2);
    errdefer map.deinit();

    var room = try Room.config(Pos.init(2, 2), Pos.init(9, 9));
    room.setDark();
    try mapgen.addRoom(map, room);

    try mapgen.addRoom(map, try Room.config(Pos.init(27, 5), Pos.init(35, 10)));
    try mapgen.addEastCorridor(map, Pos.init(9, 5), Pos.init(27, 8), 13);

    try mapgen.addRoom(map, try Room.config(Pos.init(4, 12), Pos.init(20, 19)));

    try mapgen.addSouthCorridor(map, Pos.init(4, 9), Pos.init(18, 12), 10);

    try map.addItem(Item.config(10, 16, .gold));

    if (config.player) |p| {
        try map.setMonster(p, 6, 6);
    }

    return map;
}

//
// Unit tests
//

test "use test level" {
    const config = LevelConfig{
        .allocator = std.testing.allocator,
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
        .mapgen = .TEST,
    };

    const map = try createTestLevel(config);
    defer map.deinit();
}

// EOF
