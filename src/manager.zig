const std = @import("std");

const expect = std.testing.expect;

// ===================
//
// Management of dynamic items (items, monsters, etc.)
//
// Wraps a DoublyLinkedList and an allocator and an iterator
//

pub fn Manager(comptime T: type) type {
    return struct {
        const Self = @This();
        const L = std.DoublyLinkedList(T);

        allocator: std.mem.Allocator,
        list: L = .{},

        pub const Iterator = struct {
            curr: ?*L.Node = null,

            pub fn next(self: *Self.Iterator) ?*T {
                if (self.curr == null) {
                    return null;
                }

                const ret = self.curr.?;
                self.curr = ret.next;
                return &ret.data;
            }
        };

        pub fn config(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .list = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.list.pop()) |n| {
                self.allocator.destroy(n);
            }
        }

        pub fn node(self: *Self, t: T) !*T {
            var n = try self.allocator.create(L.Node);

            n.data = t;
            self.list.append(n); // at end
            return &n.data;
        }

        pub fn deinitNode(self: *Self, t: *T) void {
            const pint: usize = @intFromPtr(t) - @offsetOf(L.Node, "data");
            const np: *L.Node = @ptrFromInt(pint);
            self.list.remove(np);
            self.allocator.destroy(np);
        }

        pub fn iterator(self: *Self) Self.Iterator {
            return .{ .curr = self.list.first };
        }

        // TODO: search ?
    };
}

//
// Unit Tests
//

const Frotz = struct {
    i: u32,
    j: f32,
};

test "basic tests" {
    const FrotzManager = Manager(Frotz);
    var fm = FrotzManager.config(std.testing.allocator);
    defer fm.deinit();

    const f = try fm.node(.{ .i = 0, .j = 1.1 });
    errdefer fm.deinitNode(f);

    const f1 = try fm.node(.{ .i = 1, .j = 1.2 });
    errdefer fm.deinitNode(f1);
    const f2 = try fm.node(.{ .i = 2, .j = 1.2 });
    errdefer fm.deinitNode(f2);
    const f3 = try fm.node(.{ .i = 3, .j = 1.2 });
    errdefer fm.deinitNode(f3);

    // Create then remove and should not see it
    const f4 = try fm.node(.{ .i = 1000, .j = 1.2 });
    fm.deinitNode(f4);

    // Iterator

    var it = fm.iterator();
    var i: u32 = 0;
    while (it.next()) |frotz| {
        try expect(frotz.i == i);
        i = frotz.i + 1;
        fm.deinitNode(frotz);
    }

    try expect(i == 4); // Last one seen plus one
}

test "clean the list" {
    const FrotzManager = Manager(Frotz);
    var fm = FrotzManager.config(std.testing.allocator);
    defer fm.deinit();

    for (0..10) |x| {
        _ = try fm.node(.{ .i = @intCast(x), .j = 1.1 });
    }
}

//
// Visualization needs implementation
//

// EOF
