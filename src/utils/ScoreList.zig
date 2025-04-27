const std = @import("std");

const Self = @This();

pub const Score = struct {
    name: []const u8,
    score: usize,
    // TODO: win or quit etc
};

// Hides the fact that there is an ArrayList inside
pub const Iterator = struct {
    i: usize = 0,
    s: *Self,

    pub fn config(s: *Self) Iterator {
        return .{ .i = 0, .s = s };
    }

    pub fn next(self: *Iterator) ?Score {
        const val = self.i;
        self.i += 1;
        const items = self.s.scores.items;
        if (val >= items.len) {
            return null;
        }
        return items[val];
    }
};

//
// Fields of ScoreList
//

allocator: std.mem.Allocator = undefined,
scores: std.ArrayList(Score) = undefined,

//
// Constructor and destructor
//
pub fn init(a: std.mem.Allocator) !Self {
    const s = std.ArrayList(Score).init(a);
    return .{
        .allocator = a,
        .scores = s,
    };
}

pub fn deinit(self: *Self) void {
    for (self.scores.items) |score| {
        self.allocator.free(score.name);
    }
    self.scores.deinit();
}

//
// Methods
//

pub fn append(self: *Self, name: []const u8, score: usize) !void {
    const n = try self.allocator.dupe(u8, name);
    const s: Score = .{ .name = n, .score = score };
    try self.scores.append(s);
}

pub fn iterator(self: *Self) Iterator {
    return Iterator.config(self);
}

//
// Unit Tests
//

const expect = std.testing.expect;

test "basic ScoreList tests" {
    var s = try Self.init(std.testing.allocator);
    defer s.deinit();

    try s.append("nobody", 4);
    try s.append("somebody", 100);
    try s.append("otherbody", 100);

    // Iterator

    var it = s.iterator();
    var i: usize = 0;
    while (it.next()) |_| {
        i += 1;
    }
    try expect(i == 3);
}

// EOF
