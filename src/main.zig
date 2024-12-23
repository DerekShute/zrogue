const std = @import("std");
const curses = @import("curses.zig");
const game = @import("game.zig");

// TODO terminal size, map size constants

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var providers = try curses.init(allocator);
    const display = providers.d.provider();
    const input = providers.i.provider();
    defer display.endwin();

    try game.run(allocator, input, display);
}

//
// Unit tests
//

test "run the game" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // TODO: use testing allocator

    const MockDisplayProvider = @import("display.zig").MockDisplayProvider;
    const MockInputProvider = @import("input.zig").MockInputProvider;

    var md = MockDisplayProvider.init(.{ .maxx = 80, .maxy = 24 });
    const display = md.provider();
    defer display.endwin();

    var mi = MockInputProvider.init(.{ .keypress = '*' });
    const input = mi.provider();

    try game.run(allocator, input, display);

    // TODO: must be a way to test for all leaks (of display still init, etc.)
}

// EOF
