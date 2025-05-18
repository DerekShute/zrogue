//!
//! Generate visualization of common structures
//!
//!
//! This is built and run as part of the 'visual' target and outputs
//! a handcrafted YAML description of structures within instrumented
//! modules.
//!
//! A Python script will take this YAML and format the Graphviz
//! diagram.

const std = @import("std");

const map = @import("src/map.zig");
const player = @import("src/player.zig");
const thing = @import("src/thing.zig");
const itemFields = @import("src/item.zig").fields;
const zrogue = @import("src/zrogue.zig");
const log = @import("src/message_log.zig");

fn printer(array: []const []const u8) void {
    for (array) |name| {
        std.debug.print("{s}\n", .{name});
    }
}

pub fn main() !void {
    std.debug.print("---\n", .{});
    printer(map.items_fields);
    printer(map.map_fields);
    printer(map.room_fields);
    printer(map.place_fields);
    printer(player.player_fields);
    printer(thing.thing_fields);
    printer(zrogue.region_fields);
    printer(zrogue.pos_fields);
    printer(zrogue.action_fields);
    printer(itemFields);
    printer(log.log_fields);
}

// EOF
