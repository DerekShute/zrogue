const std = @import("std");
const zrogue = @import("../zrogue.zig");

const Pos = zrogue.Pos;
const Thing = @import("../thing.zig").Thing;

//
// Encapsulate arguments
//

pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
    mapgen: enum {
        TEST,
        ROGUE,
    },
};

//
// Published factories
//

pub const createTestLevel = @import("test_level.zig").createTestLevel;
pub const createRogueLevel = @import("rogue_level.zig").createRogueLevel;

// TODO: common functions...
// * dig corridor given endpoint and some point in the middle
// * draw a rectangular room
// * locate a place for a door
// * draw a maze

// EOF
