const std = @import("std");

pub const DisplayProvider = struct {

    // Type-erased pointer to the display implementation
    ptr: *anyopaque,
    vtable: *const DisplayVTable,

    // VTable for implementation to manage
    pub const DisplayVTable = struct {
        // constructor/destructor
        endwin: *const fn (ctx: *anyopaque) void,
        // methods
        erase: *const fn (ctx: *anyopaque) void,
        getmaxx: *const fn (ctx: *anyopaque) u16,
        getmaxy: *const fn (ctx: *anyopaque) u16,
        mvaddch: *const fn (ctx: *anyopaque, x: u16, y: u16, ch: u8) void,
        refresh: *const fn (ctx: *anyopaque) void,
    };

    // Constructor and destructor

    pub inline fn endwin(self: DisplayProvider) void {
        self.vtable.endwin(self.ptr);
    }

    // Methods

    pub inline fn erase(self: DisplayProvider) void {
        return self.vtable.erase(self.ptr);
    }

    pub inline fn getmaxx(self: DisplayProvider) u16 {
        return self.vtable.getmaxx(self.ptr);
    }

    pub inline fn getmaxy(self: DisplayProvider) u16 {
        return self.vtable.getmaxy(self.ptr);
    }

    pub inline fn mvaddch(self: DisplayProvider, x: u16, y: u16, ch: u8) !void {
        self.vtable.mvaddch(self.ptr, x, y, ch);
    }

    pub inline fn refresh(self: DisplayProvider) void {
        return self.vtable.refresh(self.ptr);
    }
}; // DisplayProvider

//
// MockDisplayProvider for testing purposes
//

pub const MockDisplayProvider = struct {
    // TODO: 'initialized' field to track use-after-deinit
    maxx: u16,
    maxy: u16,
    x: u16,
    y: u16,
    // todo: cursor

    pub const MockDisplayConfig = struct {
        maxx: u16,
        maxy: u16,
        // TODO cursor
    };

    // Constructor (not sure why this is in two parts)

    pub fn init(config: MockDisplayConfig) MockDisplayProvider {
        return MockDisplayProvider{
            .maxx = config.maxx,
            .maxy = config.maxy,
            .x = 0,
            .y = 0,
        };
    }

    pub fn provider(self: *MockDisplayProvider) DisplayProvider {
        return .{
            .ptr = self,
            .vtable = &.{
                .endwin = endwin,
                .erase = erase,
                .getmaxx = getmaxx,
                .getmaxy = getmaxy,
                .mvaddch = mvaddch,
                .refresh = refresh,
            },
        };
    }

    //
    // Methods
    //

    fn endwin(ptr: *anyopaque) void {
        _ = ptr;
        return;
    }

    fn erase(ptr: *anyopaque) void {
        _ = ptr;
        return;
    }

    fn getmaxx(ptr: *anyopaque) u16 {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        return self.maxx;
    }

    fn getmaxy(ptr: *anyopaque) u16 {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        return self.maxy;
    }

    fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) void {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = ch;
        return;
    }

    fn refresh(ptr: *anyopaque) void {
        _ = ptr;
        return;
    }
}; // MockDisplayProvider

//
// Unit tests
//

test "Basic use of mock provider" {
    var p = MockDisplayProvider.init(.{ .maxx = 50, .maxy = 50 });
    var d = p.provider();
    defer d.endwin();

    d.erase();
    d.refresh();

    try std.testing.expect(d.getmaxx() == 50);
    try std.testing.expect(d.getmaxy() == 50);
}

// EOF
