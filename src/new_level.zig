pub const std = @import("std");
const zrogue = @import("zrogue.zig");
const Pos = zrogue.Pos;

const mapgen = @import("mapgen/mapgen.zig");

//
// Level generation from the top
//

pub const LevelConfig = mapgen.LevelConfig;
pub const createLevel = mapgen.createTestLevel;

// Unit tests

test "use test level" {
    // TODO need mock Thing
    const allocator = std.testing.allocator;
    const config = LevelConfig{
        .allocator = allocator,
        .xSize = zrogue.MAPSIZE_X,
        .ySize = zrogue.MAPSIZE_Y,
    };

    const map = try mapgen.createTestLevel(config);
    defer map.deinit();
}

// EOF
