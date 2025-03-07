const std = @import("std");
const zrogue = @import("zrogue.zig");

// ===================
//
// Record of messages sent to an entity (presumably a player)
//
// TODO: Right now, depth of one
//
pub const MessageLog = struct {
    allocator: std.mem.Allocator,
    memory: [zrogue.MESSAGE_MAXSIZE]u8 = undefined,
    buffer: []u8 = &.{},

    // CONSTRUCTORS

    pub fn init(allocator: std.mem.Allocator) !*MessageLog {
        const log: *MessageLog = try allocator.create(MessageLog);
        errdefer allocator.free(log);
        log.allocator = allocator;
        log.buffer = &.{}; // Empty
        return log;
    }

    pub fn deinit(self: *MessageLog) void {
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    // METHODS

    pub fn add(self: *MessageLog, msg: []const u8) void {
        self.buffer = &self.memory; // Reset slice to max length and content
        @memcpy(self.buffer[0..msg.len], msg);
        self.buffer = self.buffer[0..msg.len]; // Fix up the slice for length
    }

    // TODO set up to append:  self.buffer = self.buffer[msg.len..];

    pub fn get(self: *MessageLog) []u8 {
        return self.buffer;
    }

    pub fn clear(self: *MessageLog) void {
        self.buffer = &.{}; // Reset to zero
    }
};

//
// Unit Tests
//

test "allocate and add messages" {
    const log: *MessageLog = try MessageLog.init(std.testing.allocator);
    defer log.deinit();

    // Empty to begin
    var empty = log.get();
    try std.testing.expect(empty.len == 0);

    log.add("A LOG MESSAGE");
    try std.testing.expect(std.mem.eql(u8, log.get(), "A LOG MESSAGE"));

    // Repeat succeeds
    try std.testing.expect(std.mem.eql(u8, log.get(), "A LOG MESSAGE"));

    // Change it
    log.add("SECOND MESSAGE");
    try std.testing.expect(std.mem.eql(u8, log.get(), "SECOND MESSAGE"));

    // Clearing it empties it
    log.clear();
    empty = log.get();
    try std.testing.expect(empty.len == 0);

    // Change it
    log.add("SECOND MESSAGE");
    try std.testing.expect(std.mem.eql(u8, log.get(), "SECOND MESSAGE"));

    // (It does not test equal against superstrings or substrings)
    try std.testing.expect(!std.mem.eql(u8, log.get(), "SECOND MESSAGE2"));
    try std.testing.expect(!std.mem.eql(u8, log.get(), "SECOND MESSA"));
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var log_fields = genFields(MessageLog);

// EOF
