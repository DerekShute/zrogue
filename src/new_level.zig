const std = @import("std");
const mapgen = @import("mapgen/mapgen.zig");
const zrogue = @import("zrogue.zig");

const Map = @import("map.zig").Map;
const Pos = zrogue.Pos;

//
// Level generation from the top
//

pub const LevelConfig = mapgen.LevelConfig;

pub fn createLevel(config: LevelConfig) !*Map {
    return switch (config.mapgen) {
        .TEST => try mapgen.createTestLevel(config),
    };
}

// Unit tests

test "use test level" {
    // TODO need mock Thing
    const allocator = std.testing.allocator;
    const config = LevelConfig{
        .allocator = allocator,
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
        .mapgen = .TEST,
    };

    const map = try createLevel(config);
    defer map.deinit();
}

// EOF
