//!
//! Management of dynamic items (items, monsters, etc.)
//!
//! Wraps a DoublyLinkedList and an allocator and an iterator
//!

const std = @import("std");

pub const ManagedNode = std.DoublyLinkedList.Node;
const ManagedList = std.DoublyLinkedList;

pub fn Manager(comptime T: type) type {
    // Assumes that there's a method 'getNode' that returns the node pointer
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        list: ManagedList = undefined,

        pub const Iterator = struct {
            curr: ?*ManagedNode = null,

            pub fn next(self: *Self.Iterator) ?*T {
                if (self.curr == null) {
                    return null;
                }

                const ret = self.curr.?;
                self.curr = ret.next;
                const ret_t: *T = @fieldParentPtr("node", ret); // backwards
                return ret_t;
            }
        };

        // Methods

        pub fn config(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .list = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.list.pop()) |n| {
                const pop: *T = @fieldParentPtr("node", n);
                self.allocator.destroy(pop);
            }
        }

        pub fn initNode(self: *Self, t: T) !*T {
            var n = try self.allocator.create(T);
            errdefer self.allocator.destroy(n);

            n = t;
            self.list.append(n); // at end
            return n;
        }

        pub fn deinitNode(self: *Self, t: *T) void {
            self.list.remove(t.getNode());
            self.allocator.destroy(t);
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
const expect = std.testing.expect;

const Frotz = struct {
    node: ManagedNode = .{},
    i: u32,
    j: f32,

    pub fn getNode(self: Frotz) *ManagedNode {
        return &self.node;
    }
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
