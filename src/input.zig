const std = @import("std");
const zrogue = @import("zrogue.zig");
const ZrogueError = zrogue.ZrogueError;
const Command = zrogue.Command;

// ===================
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
    commandlist: []Command,
    index: u16 = 0,

    pub const MockInputConfig = struct {
        commands: []Command,
        // TODO cursor
    };

    pub fn init(config: MockInputConfig) MockInputProvider {
        return MockInputProvider{
            .commandlist = config.commands,
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
        const i = self.index;
        if (i >= self.commandlist.len)
            return ZrogueError.IndexOverflow;
        self.index = self.index + 1;
        return self.commandlist[i];
        // TODO: error if no more keypresses to provide
    }
}; // MockInputProvider

//
// Unit tests
//

test "Basic use of mock input provider" {
    var commandlist = [_]Command{
        Command.goWest,
        Command.quit,
    };
    var p = MockInputProvider.init(.{ .commands = &commandlist });
    var i = p.provider();

    try std.testing.expect(try i.getCommand() == Command.goWest);
    try std.testing.expect(try i.getCommand() == Command.quit);
    try std.testing.expectError(ZrogueError.IndexOverflow, i.getCommand());
}

// Visualize
const genFields = @import("visual.zig").genFields;
pub var input_fields = genFields(InputProvider);

// EOF
