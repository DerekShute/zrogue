const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

// ===================
//
// 2-D array
//

pub fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        i: []T,
        height: usize,
        width: usize,

        // TODO: iterator

        pub fn config(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
            const items = try allocator.alloc(T, @intCast(height * width));
            errdefer allocator.free(items);

            return .{
                .allocator = allocator,
                .i = items,
                .height = height,
                .width = width,
            };
        }

        pub fn deinit(self: Self) void {
            const allocator = self.allocator;
            allocator.free(self.i);
        }

        pub fn find(self: Self, x: usize, y: usize) !*T {
            if (x >= self.width)
                return error.Overflow;
            if (y >= self.height)
                return error.Overflow;

            const loc: usize = (x + y * self.width);
            return &self.i[loc];
        }
    };
}

//
// Unit Tests
//

const Frotz = struct {
    i: u32,
    j: f32 = 0.0,
};

test "basic tests" {
    const FrotzGrid = Grid(Frotz);
    var fg = try FrotzGrid.config(std.testing.allocator, 100, 100);
    defer fg.deinit();

    _ = try fg.find(10, 10);
    _ = try fg.find(0, 0);
    try expectError(error.Overflow, fg.find(100, 100));
    try expectError(error.Overflow, fg.find(1000, 0));
}

test "alloc does not work" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const FrotzGrid = Grid(Frotz);

    try expectError(error.OutOfMemory, FrotzGrid.config(failing.allocator(), 10, 10));
}

// EOF
