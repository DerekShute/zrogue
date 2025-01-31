const std = @import("std");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const Command = zrogue.Command;

//
// Input provider - pull commands out of the player/user
//

pub const InputProvider = struct {
    // Type-erased pointer to the display implementation
    ptr: *anyopaque,
    vtable: *const InputVTable,

    // VTable for implementation to manage
    pub const InputVTable = struct {
        // methods
        getCommand: *const fn (ctx: *anyopaque) ZrogueError!Command,
    };

    //
    // Methods
    //

    pub inline fn getCommand(self: InputProvider) ZrogueError!Command {
        return self.vtable.getCommand(self.ptr);
    }
};

//
// MockInputProvider for testing purposes
//

pub const MockInputProvider = struct {
    command: Command, // TODO slice/array with index

    pub const MockInputConfig = struct {
        command: Command,
        // TODO cursor
    };

    pub fn init(config: MockInputConfig) MockInputProvider {
        return MockInputProvider{
            .command = config.command,
        };
    }

    pub fn provider(self: *MockInputProvider) InputProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .getCommand = getCommand,
            },
        };
    }

    //
    // Methods
    //

    fn getCommand(ptr: *anyopaque) ZrogueError!Command {
        const self: *MockInputProvider = @ptrCast(@alignCast(ptr));
        return self.command;
        // TODO: error if no more keypresses to provide
    }
}; // MockInputProvider

//
// Unit tests
//

test "Basic use of mock input provider" {
    var p = MockInputProvider.init(.{ .command = Command.quit });
    var i = p.provider();

    try std.testing.expect(try i.getCommand() == Command.quit);
}

// EOF
