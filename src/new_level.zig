const std = @import("std");
const mapgen = @import("mapgen/mapgen.zig");
const zrogue = @import("zrogue.zig");

const Map = @import("map.zig").Map;
//const Pos = zrogue.Pos;

//
// Level generation from the top
//

pub const LevelConfig = mapgen.LevelConfig;

pub fn createLevel(config: LevelConfig) !*Map {
    return switch (config.mapgen) {
        .TEST => try mapgen.createTestLevel(config),
        .ROGUE => try mapgen.createRogueLevel(config),
    };
}

// EOF
