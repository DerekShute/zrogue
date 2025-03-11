const std = @import("std");
const zrogue = @import("../zrogue.zig");
pub const Pos = zrogue.Pos;
pub const Item = @import("../item.zig").Item;
pub const Map = @import("../map.zig").Map;
pub const Room = @import("../map.zig").Room;
pub const Thing = @import("../thing.zig").Thing;

pub const createTestLevel = @import("test_level.zig").createTestLevel;

// Encapsulate arguments
pub const LevelConfig = struct {
    allocator: std.mem.Allocator = undefined,
    player: ?*Thing = null,
    xSize: Pos.Dim = -1,
    ySize: Pos.Dim = -1,
};

// EOF
