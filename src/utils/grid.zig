const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const ZrogueError = @import("../zrogue.zig").ZrogueError;

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

        pub const Iterator = struct {
            array: []T = undefined,
            curr: usize = 0,

            pub fn next(self: *Self.Iterator) ?*T {
                if (self.curr < self.array.len) {
                    const ret = &self.array[self.curr];
                    self.curr += 1;
                    return ret;
                }
                return null;
            }
        };

        pub fn iterator(self: Self) Self.Iterator {
            return .{
                .array = self.i,
                .curr = 0,
            };
        }

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

        pub fn find(self: Self, x: usize, y: usize) ZrogueError!*T {
            if (x >= self.width)
                return ZrogueError.IndexOverflow;
            if (y >= self.height)
                return ZrogueError.IndexOverflow;

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
const FrotzGrid = Grid(Frotz);

test "basic tests" {
    var fg = try FrotzGrid.config(std.testing.allocator, 100, 100);
    defer fg.deinit();

    _ = try fg.find(10, 10);
    _ = try fg.find(0, 0);
    try expectError(ZrogueError.IndexOverflow, fg.find(100, 100));
    try expectError(ZrogueError.IndexOverflow, fg.find(1000, 0));
}

test "iterator" {
    var fg = try FrotzGrid.config(std.testing.allocator, 100, 100);
    defer fg.deinit();

    var i = fg.iterator();
    var x: u32 = 0;
    while (i.next()) |f| {
        f.i = x;
        x += 1;
    }

    var f = try fg.find(0, 0);
    try expect(f.i == 0);
    f = try fg.find(99, 0);
    try expect(f.i == 99);
    f = try fg.find(99, 99);
    try expect(f.i == 9999);
}

test "alloc does not work" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, FrotzGrid.config(failing.allocator(), 10, 10));
}

// EOF
