const std = @import("std");

const Random = std.Random;
const expect = std.testing.expect;

//
// Entropy generation convenience
//
// I am not thinking of good things to call this
//

pub const Roller = struct {
    ptr: *anyopaque = undefined,
    vtable: VTable = undefined,

    const IntType = u8;

    pub const VTable = struct {
        roll: *const fn (ptr: *anyopaque, maxval: IntType) IntType,
    };

    pub fn roll(self: Roller, maxval: IntType) IntType {
        // 0 <= x < maxval
        return self.vtable.roll(self.ptr, maxval);
    }

    // TODO comptime-known "2d6" behavior

    // TODO figure out if really wants 1 <= X <= maxval based on usage
};

pub const ConstRoller = struct {
    value: Roller.IntType = undefined,

    pub fn config(val: Roller.IntType) ConstRoller {
        return .{
            .value = val,
        };
    }

    pub fn roller(self: *ConstRoller) Roller {
        return .{
            .ptr = self,
            .vtable = .{
                .roll = roll,
            },
        };
    }

    pub fn set(self: *ConstRoller, new: Roller.IntType) void {
        self.value = new;
    }

    fn roll(ptr: *anyopaque, maxval: Roller.IntType) Roller.IntType {
        const self: *ConstRoller = @ptrCast(@alignCast(ptr));
        return self.value % maxval;
    }
};

pub const SetRoller = struct {
    values: []Roller.IntType = undefined,
    index: usize = 0,

    pub fn config(vals: []Roller.IntType) SetRoller {
        return .{
            .values = vals,
        };
    }

    pub fn roller(self: *SetRoller) Roller {
        return .{
            .ptr = self,
            .vtable = .{
                .roll = roll,
            },
        };
    }

    fn roll(ptr: *anyopaque, maxval: Roller.IntType) Roller.IntType {
        const self: *SetRoller = @ptrCast(@alignCast(ptr));
        const i = self.index;
        if (i >= self.values.len) {
            std.debug.panic("SetRoller out of values\n", .{}); // noreturn
        }
        self.index = self.index + 1;
        return self.values[i] % maxval;
    }
};

pub const RandomRoller = struct {
    gen: Random = undefined,

    pub fn config() RandomRoller {
        // I am not sure if there is a better approach here
        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });

        return .{
            .gen = prng.random(),
        };
    }

    pub fn roller(self: *RandomRoller) Roller {
        return .{
            .ptr = self,
            .vtable = .{
                .roll = roll,
            },
        };
    }

    fn roll(ptr: *anyopaque, maxval: Roller.IntType) Roller.IntType {
        const self: *RandomRoller = @ptrCast(@alignCast(ptr));
        return self.gen.int(Roller.IntType) % maxval;
    }
};

// Unit tests

test "use testing/constant roller" {
    var constroller = ConstRoller.config(8);
    var r = constroller.roller();

    try expect(r.roll(9) == 8);
    try expect(r.roll(8) == 0);
    try expect(r.roll(3) == 2);

    constroller.set(3);
    try expect(r.roll(9) == 3);
}

test "use randomizing roller" {
    var randroller = RandomRoller.config();
    var r = randroller.roller();

    try expect(r.roll(9) <= 9);
}

test "use set roller" {
    var list = [_]Roller.IntType{ 0, 1, 2, 3 };
    var setroller = SetRoller.config(&list);
    var r = setroller.roller();

    try expect(r.roll(10) == 0);
    try expect(r.roll(10) == 1);
    try expect(r.roll(10) == 2);
    try expect(r.roll(10) == 3);

    // To induce panic
    // try expect(r.roll(10) == 4);
}
// EOF
