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

    pub fn roll(self: Randomizer, comptime maxval: IntType) IntType {
        // 0 <= x < maxval
        // TODO maxval known at comptime and must be nonzero
        return self.gen.int(IntType) % maxval;
    }

    // TODO comptime-known "2d6" behavior

    // TODO figure out if really wants 1 <= X <= maxval based on usage
};

// Unit tests

// This is swiped from std/Random/test.zig -- it is not exposed
const SequentialPrng = struct {
    next_value: u8,

    pub fn init() SequentialPrng {
        return .{
            .next_value = 0,
        };
    }

    pub fn random(self: *SequentialPrng) Random {
        return Random.init(self, fill);
    }

    pub fn fill(self: *SequentialPrng, buf: []u8) void {
        for (buf) |*b| {
            b.* = self.next_value;
        }
        self.next_value +%= 1;
    }
};

test "use randomizer" {
    var rng = SequentialPrng.init();
    const random = rng.random();

    const r = Randomizer.config(random);

    rng.next_value = 10;
    try expect(r.roll(20) == 10);
    rng.next_value = 20;
    for (0..10) |i| {
        try expect(r.roll(10) == i);
    }
    rng.next_value = 5;
    try expect(r.roll(6) == 5);
    try expect(r.roll(6) == 0);
}

// EOF
