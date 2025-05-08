const std = @import("std");
const StructuredRecords = @import("StructuredRecords.zig").StructuredRecords;

const Self = @This();

const THIS_VERSION = 1;

pub const Error = error{
    ParseError,
    WrongVersion,
};

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

const ScoreRecords = StructuredRecords(Score);

//
// Fields of ScoreList
//

allocator: std.mem.Allocator = undefined,
scores: std.ArrayList(Score) = undefined,

//
// Constructor and destructor
//
pub fn load(a: std.mem.Allocator, path: []const u8) !Self {
    var ret = Self{
        .allocator = a,
        .scores = std.ArrayList(Score).init(a),
    };
    errdefer ret.deinit();

    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();

    const records = ScoreRecords.loadFile(arena.allocator(), THIS_VERSION, path) catch |err| switch (err) {
        error.FileNotFound => &.{},
        ScoreRecords.Error.EmptyFile => &.{},
        ScoreRecords.Error.ParseError => return Error.ParseError,
        ScoreRecords.Error.WrongVersion => return Error.WrongVersion,
        else => return err,
    };

    for (records) |record| {
        try ret.append(record.name, record.score);
    }

    return ret;
}

// For testing purposes
pub fn init(a: std.mem.Allocator, data: []const u8) !Self {
    var ret = Self{
        .allocator = a,
        .scores = std.ArrayList(Score).init(a),
    };
    errdefer ret.deinit();

    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();

    // TODO: probably a way to consolidate in a local routine
    const records = ScoreRecords.loadData(arena.allocator(), THIS_VERSION, data) catch |err| switch (err) {
        ScoreRecords.Error.EmptyFile => &.{},
        ScoreRecords.Error.ParseError => return Error.ParseError,
        ScoreRecords.Error.WrongVersion => return Error.WrongVersion,
        else => return err,
    };

    for (records) |record| {
        try ret.append(record.name, record.score);
    }

    return ret;
}

pub fn finalize(self: *Self, path: []const u8) !void {
    defer self.deinit();

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try ScoreRecords.write(arena.allocator(), THIS_VERSION, self.scores.items, file.writer());
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

fn cmpScore(context: void, a: Score, b: Score) bool {
    _ = context;
    if (a.score < b.score) {
        return true;
    } else {
        return false;
    }
}

pub fn append(self: *Self, name: []const u8, score: usize) !void {
    const n = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(n);

    const s: Score = .{ .name = n, .score = score };
    try self.scores.append(s);

    // Now sort it
    const x = try self.scores.toOwnedSlice();
    std.mem.sort(Score, x, {}, cmpScore);
    self.scores = std.ArrayList(Score).fromOwnedSlice(self.allocator, x);
}

pub fn iterator(self: *Self) Iterator {
    return Iterator.config(self);
}

pub fn getScore(self: *Self, index: usize) usize {
    return self.scores.items[index].score;
}
pub fn getName(self: *Self, index: usize) []const u8 {
    return self.scores.items[index].name;
}

pub fn getLength(self: *Self) usize {
    return self.scores.items.len;
}

//
// Unit Tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const FailingAllocator = std.testing.FailingAllocator;
const t_alloc = std.testing.allocator;

test "basic ScoreList tests" {
    var s = try Self.init(t_alloc, "");
    defer s.deinit();

    // No test data or file: empty
    try expect(s.getLength() == 0);

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

test "initialize with test data" {
    const test_data =
        \\ version: 1
        \\ records:
        \\   - name: moe
        \\     score: 100
        \\   - name: larry
        \\     score: 200
        \\   - name: curly
        \\     score: 300
    ;

    var s = try Self.init(t_alloc, test_data);
    defer s.deinit();

    try expect(s.getLength() == 3);
    try expect(std.mem.eql(u8, s.getName(0), "moe"));
    try expect(s.getScore(2) == 300);
    // append will sort in order of the numerical score
    try s.append("nobody", 4);
    try expect(s.getScore(0) == 4);
    try expect(s.getScore(3) == 300);

    // index out of bounds will panic.  This is slice behavior
    // try expect(s.getScore(100) == 4);
}

test "load from nonexistent file" {
    // Expect it to give zero items

    var s = try Self.load(t_alloc, "nonexistent-file.yml");
    defer s.deinit();

    try expect(s.scores.items.len == 0);
}

test "file corruption" {
    // Until a better idea presents itself

    const test_data =
        \\ version: 1
        \\ records:
        \\   - name: moe
        \\     score: 0
        \\   - name: larry
        \\   - name: curly
        \\     score: 100
    ;

    try expectError(Error.ParseError, Self.init(t_alloc, test_data));
}

test "version test" {

    // Until a better idea presents itself

    const test_data =
        \\ version: 0
        \\ records:
        \\   - name: moe
        \\   - name: larry
        \\   - name: curly
    ;

    try expectError(Error.WrongVersion, Self.init(t_alloc, test_data));
}

test "allocate ScoreList" {
    var failing = FailingAllocator.init(t_alloc, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    try expectError(error.OutOfMemory, Self.init(allocator, ""));
}

test "fails to allocate on append 0" {
    // Calibrated to get off the ground and then crater
    var failing = FailingAllocator.init(t_alloc, .{ .fail_index = 2 });
    const allocator = failing.allocator();

    var s = try Self.init(allocator, "");
    defer s.deinit();

    try expectError(error.OutOfMemory, s.append("nobody", 4));
}

// EOF
