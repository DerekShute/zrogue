//
// Generate visualization of common structures
//

// https://ziggit.dev/t/error-when-generating-struct-field-names-using-zig-comptime/6319/2

const std = @import("std");

const map = @import("src/map.zig");
const player = @import("src/player.zig");
const thing = @import("src/thing.zig");
const display = @import("src/display.zig");
const input = @import("src/input.zig");
const zrogue = @import("src/zrogue.zig");
const log = @import("src/message_log.zig");

pub fn main() !void {
    std.debug.print("Map\n", .{});
    for (map.map_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("Room\n", .{});
    for (map.room_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("Player\n", .{});
    for (player.player_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("Thing\n", .{});
    for (thing.thing_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("Region\n", .{});
    for (zrogue.region_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("Pos\n", .{});
    for (zrogue.pos_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("ThingAction\n", .{});
    for (zrogue.action_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("DisplayProvider\n", .{});
    for (display.display_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("InputProvider\n", .{});
    for (input.input_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
    std.debug.print("MessageLog\n", .{});
    for (log.log_fields) |name| {
        std.debug.print(" * {s}\n", .{name});
    }
}

// EOF
