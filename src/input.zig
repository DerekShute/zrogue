const std = @import("std");
const ZrogueError = @import("zrogue.zig").ZrogueError;

pub const InputProvider = struct {
    // Type-erased pointer to the display implementation
    ptr: *anyopaque,
    vtable: *const InputVTable,

    // VTable for implementation to manage
    pub const InputVTable = struct {
        // methods
        getch: *const fn (ctx: *anyopaque) ZrogueError!usize,
    };

    //
    // Methods
    //

    pub inline fn getch(self: InputProvider) ZrogueError!usize {
        return self.vtable.getch(self.ptr);
    }
};

//
// MockInputProvider for testing purposes
//

pub const MockInputProvider = struct {
    keypress: u8, // TODO slice/array with index

    pub const MockInputConfig = struct {
        keypress: u8,
        // TODO cursor
    };

    pub fn init(config: MockInputConfig) MockInputProvider {
        return MockInputProvider{
            .keypress = config.keypress,
        };
    }

    pub fn provider(self: *MockInputProvider) InputProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .getch = getch,
            },
        };
    }

    //
    // Methods
    //

    fn getch(ptr: *anyopaque) ZrogueError!usize {
        const self: *MockInputProvider = @ptrCast(@alignCast(ptr));
        return @as(usize, self.keypress);
        // TODO: error if no more keypresses to provide
    }
}; // MockInputProvider

//
// Unit tests
//

test "Basic use of mock input provider" {
    var p = MockInputProvider.init(.{ .keypress = '*' });
    var i = p.provider();

    try std.testing.expect(try i.getch() == '*');
}

// EOF
