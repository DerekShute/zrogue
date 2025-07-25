//!
//! Unit test aggregator
//!

comptime {
    _ = @import("src/curses.zig");
    _ = @import("src/item.zig");
    _ = @import("src/map.zig");
    _ = @import("src/main.zig");
    _ = @import("src/new_level.zig");
    _ = @import("src/Feature.zig");
    _ = @import("src/Provider.zig");
    _ = @import("src/Region.zig");
    _ = @import("src/thing.zig");
    _ = @import("src/zrogue.zig");
    _ = @import("src/message_log.zig");

    _ = @import("src/mapgen/tests.zig");
    _ = @import("src/utils/tests.zig");
}

// EOF
