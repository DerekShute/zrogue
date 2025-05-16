//!
//! This is an experiment.
//!
//! The goal is to provide a scaffold for game records in a
//! version-controlled way, where record file / configuration
//! file is headed with a version that drives its acceptance or
//! interpretation.
//!
//! (Mostly, an excuse to fiddle with importing third-party code
//! and file system stuff.)
//!
//! Currently it is layered on top of zig_yaml, with the following
//! convention:
//!
//! version: <some version number agreed with the code>
//! records:
//!   - <first record>
//!   - <etc>
//!
//! If the file is empty this throws EmptyFile, and the caller can figure it
//! out.
//!
//! zig_yaml cleverly uses comptime and introspection to parse the
//! YAML file directly into the internal structure format, which I
//! imagine means that upgrading a version one user list to version
//! two (for example) would be a heavy lift.  We shall see.
//!
//! Strings and such exist in the context of the provided allocator, and
//! zig_yaml assumes that the caller explicitly pass an arena allocator and
//! manages its destruction.  I am frankly dubious.
//!

const std = @import("std");
const Yaml = @import("zig_yaml").Yaml;
const stringify = @import("zig_yaml").stringify;

pub fn StructuredRecords(comptime T: type) type {
    return struct {
        const Self = @This();

        const TType = struct {
            version: i16,
            records: []T,
        };

        pub const Error = error{
            EmptyFile,
            ParseError,
            WrongVersion,
        };

        // TODO: caller passes version -1 for no checking
        // TODO: semantic version?  This release version?
        pub fn loadData(allocator: std.mem.Allocator, version: i16, data: []const u8) ![]T {
            var yaml: Yaml = .{ .source = data };
            yaml.load(allocator) catch |err| switch (err) {
                error.OutOfMemory => return err, // Worth being specific I suppose
                else => return Error.ParseError,
            };

            if (yaml.docs.items.len == 0) {
                return Error.EmptyFile;
            }

            // First item must be the version map
            switch (yaml.docs.items[0]) {
                .map => {}, // Continue and validate
                else => return Error.ParseError,
            }

            const map = yaml.docs.items[0].map;
            if (!map.contains("version")) {
                return Error.ParseError;
            } else if (map.get("version").?.int != version) {
                return Error.WrongVersion;
            }

            const result = yaml.parse(allocator, TType) catch return Error.ParseError;
            return result.records;
        }

        pub fn loadFile(allocator: std.mem.Allocator, version: i16, path: []const u8) ![]T {
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            const source = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
            return loadData(allocator, version, source);
        }

        pub fn write(allocator: std.mem.Allocator, version: i16, data: []const T, writer: anytype) !void {
            const t: TType = .{
                .version = version,
                .records = @constCast(data),
            };
            try stringify(allocator, t, writer);
            _ = try writer.write("\n");
        }
    }; // return type
}

//
// Unit Tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_alloc = std.testing.allocator;

const TestType = StructuredRecords(i16);

test "try this out" {
    const Frotz = struct {
        numbers: []const i16,
        record: struct {
            name: []const u8,
            kind: i16,
        },
    };
    const SFType = StructuredRecords(Frotz);

    const data =
        \\ version: 1
        \\ records:
        \\   - numbers: [ 1, 2, 3 ]
        \\     record:
        \\       name: foo
        \\       kind: 1
        \\   - numbers: [ 4, 5, 6 ]
        \\     record:
        \\       name: bar
        \\       kind: 3
        \\
        \\ # EOF
        \\
    ;

    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const list = try SFType.loadData(arena.allocator(), 1, data);

    try expect(list.len == 2);
    try expect(list[1].record.kind == 3);
    try expect(std.mem.eql(u8, list[0].record.name, "foo"));
}

test "file" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();

    const list = try TestType.loadFile(arena.allocator(), 1, "test-data/test.yml");
    try expect(list.len == 2);
    try expect(list[0] == 1);
}

test "missing file" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();

    try expectError(error.FileNotFound, TestType.loadFile(arena.allocator(), 1, "no-such-file.yml"));
}

test "unexpected end of document" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const data =
        \\ --
    ;
    // We don't care about the YML specifics
    try expectError(TestType.Error.ParseError, TestType.loadData(arena.allocator(), 1, data));
}

test "corrupt file" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const Frotz = struct {
        a: i16,
        b: i16,
    };
    const SFType = StructuredRecords(Frotz);
    const data =
        \\ version: 1
        \\ records:
        \\   - a: 1
        \\     # No b
    ;

    try expectError(SFType.Error.ParseError, TestType.loadData(arena.allocator(), 1, data));
}

test "version failure" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const data =
        \\ version: 2
        \\ records:
        \\   - numbers: [ 4, 5, 6 ] # Note update to version 2
        \\   - numbers: [ 4, 5, 6 ]
    ;

    try expectError(TestType.Error.WrongVersion, TestType.loadData(arena.allocator(), 1, data));
}

test "missing version" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const data =
        \\ records:
        \\   - 1
        \\   - 2
    ;

    try expectError(TestType.Error.ParseError, TestType.loadData(arena.allocator(), 1, data));
}

test "empty data" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const data =
        \\
        \\
    ;

    try expectError(TestType.Error.EmptyFile, TestType.loadData(arena.allocator(), 1, data));
}

test "garbage" {
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const data =
        \\alkjdslfkajslfkja;ldskfja;lskfdja;lskdfjasdkfja;lkdsfjaslkdfj
    ;

    try expectError(TestType.Error.ParseError, TestType.loadData(arena.allocator(), 1, data));
}

const FailingAllocator = std.testing.FailingAllocator;
const failing_data =
    \\version: 1
    \\records: [ 1, 2, 3, 4, 5 ]
    \\
;

test "early alloc failure" {
    var failing = FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var arena = std.heap.ArenaAllocator.init(failing.allocator());
    defer arena.deinit();
    try expectError(error.OutOfMemory, TestType.loadData(arena.allocator(), 1, failing_data));
}

test "alloc failure 2" {
    var failing = FailingAllocator.init(std.testing.allocator, .{ .fail_index = 2 });
    var arena = std.heap.ArenaAllocator.init(failing.allocator());
    defer arena.deinit();
    try expectError(error.OutOfMemory, TestType.loadData(arena.allocator(), 1, failing_data));
}

test "alloc non-failure 4" {
    // If this fails then something has changed internally
    var failing = FailingAllocator.init(std.testing.allocator, .{ .fail_index = 4 });
    var arena = std.heap.ArenaAllocator.init(failing.allocator());
    defer arena.deinit();
    _ = try TestType.loadData(arena.allocator(), 1, failing_data);
}

test "write data" {
    // uses failing_data for simplicity, which has been edited to line up
    // with exactly this hands you
    var arena = std.heap.ArenaAllocator.init(t_alloc);
    defer arena.deinit();
    const records = [_]i16{ 1, 2, 3, 4, 5 };

    var buff = std.ArrayList(u8).init(t_alloc);
    defer buff.deinit();

    try TestType.write(arena.allocator(), 1, &records, buff.writer());
    try expect(std.mem.eql(u8, buff.items, failing_data));
}

// EOF
