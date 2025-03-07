const std = @import("std");

const Random = std.Random;
const expect = std.testing.expect;

//
// Entropy generation convenience
//
// I am not thinking of good things to call this
//

pub const Randomizer = struct {
    gen: Random = undefined,

    const IntType = u8;

    pub fn config(gen: Random) Randomizer {
        return .{
            .gen = gen,
        };
    }

    pub fn roll(self: Randomizer, maxval: IntType) IntType {
        // 0 <= x < maxval
        // TODO maxval must be nonzero
        return self.gen.int(IntType) % maxval;
    }

    // TODO comptime-known "2d6" behavior

    // TODO figure out if really wants 1 <= X <= maxval based on usage
};

// Unit tests

// This is swiped from std/Random/test.zig -- it is not exposed
pub const FixedPrng = struct {
    value: u8,

    pub fn init() FixedPrng {
        return .{
            .value = 0,
        };
    }

    pub fn random(self: *FixedPrng) Random {
        return Random.init(self, fill);
    }

    pub fn fill(self: *FixedPrng, buf: []u8) void {
        for (buf) |*b| {
            b.* = self.value;
        }
    }
};

test "use randomizer" {
    var rng = FixedPrng.init();
    const random = rng.random();

    const r = Randomizer.config(random);

    rng.value = 10;
    try expect(r.roll(20) == 10);
    for (0..10) |i| {
        rng.value = @intCast(20 + i);
        try expect(r.roll(10) == i);
    }
    rng.value = 5;
    try expect(r.roll(6) == 5);
    rng.value = 6;
    try expect(r.roll(6) == 0);
}

// EOF
