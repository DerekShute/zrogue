const std = @import("std");
const zrogue = @import("zrogue.zig");
const MapTile = zrogue.MapTile;
const ZrogueError = zrogue.ZrogueError;

// ===================
//
// Provides the display interface
//
pub const DisplayProvider = struct {

    // Type-erased pointer to the display implementation
    ptr: *anyopaque,
    vtable: *const DisplayVTable,

    // VTable for implementation to manage
    pub const DisplayVTable = struct {
        // constructor/destructor
        endwin: *const fn (ctx: *anyopaque) void,
        // methods
        erase: *const fn (ctx: *anyopaque) ZrogueError!void,
        getmaxx: *const fn (ctx: *anyopaque) ZrogueError!u16,
        getmaxy: *const fn (ctx: *anyopaque) ZrogueError!u16,
        mvaddch: *const fn (ctx: *anyopaque, x: u16, y: u16, ch: u8) ZrogueError!void,
        refresh: *const fn (ctx: *anyopaque) ZrogueError!void,
        setTile: *const fn (ctx: *anyopaque, x: u16, y: u16, t: MapTile) ZrogueError!void,
    };

    // Constructor and destructor

    pub inline fn endwin(self: DisplayProvider) void {
        self.vtable.endwin(self.ptr);
    }

    // Methods

    pub inline fn erase(self: DisplayProvider) ZrogueError!void {
        return self.vtable.erase(self.ptr);
    }

    pub inline fn getmaxx(self: DisplayProvider) ZrogueError!u16 {
        return self.vtable.getmaxx(self.ptr);
    }

    pub inline fn getmaxy(self: DisplayProvider) ZrogueError!u16 {
        return self.vtable.getmaxy(self.ptr);
    }

    pub inline fn mvaddch(self: DisplayProvider, x: u16, y: u16, ch: u8) ZrogueError!void {
        try self.vtable.mvaddch(self.ptr, x, y, ch);
    }

    pub inline fn refresh(self: DisplayProvider) ZrogueError!void {
        return self.vtable.refresh(self.ptr);
    }

    pub inline fn setTile(self: DisplayProvider, x: u16, y: u16, t: MapTile) ZrogueError!void {
        try self.vtable.setTile(self.ptr, x, y, t);
    }
}; // DisplayProvider

//
// MockDisplayProvider for testing purposes
//

pub const MockDisplayProvider = struct {
    initialized: bool,
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
            .initialized = true,
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
                .setTile = setTile,
            },
        };
    }

    //
    // Methods
    //

    fn endwin(ptr: *anyopaque) void {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        self.initialized = false;
        return;
    }

    fn erase(ptr: *anyopaque) ZrogueError!void {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return ZrogueError.NotInitialized;
        }
        return;
    }

    fn getmaxx(ptr: *anyopaque) ZrogueError!u16 {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return ZrogueError.NotInitialized;
        }
        return self.maxx;
    }

    fn getmaxy(ptr: *anyopaque) ZrogueError!u16 {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        if (!self.initialized) {
            return ZrogueError.NotInitialized;
        }
        return self.maxy;
    }

    fn mvaddch(ptr: *anyopaque, x: u16, y: u16, ch: u8) ZrogueError!void {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = ch;
        return;
    }

    fn refresh(ptr: *anyopaque) ZrogueError!void {
        _ = ptr;
        return;
    }

    fn setTile(ptr: *anyopaque, x: u16, y: u16, t: MapTile) ZrogueError!void {
        const self: *MockDisplayProvider = @ptrCast(@alignCast(ptr));
        _ = x;
        _ = y;
        _ = self;
        _ = t;
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

    try d.erase();
    try d.refresh();

    try std.testing.expect(try d.getmaxx() == 50);
    try std.testing.expect(try d.getmaxy() == 50);
}

test "Method use after endwin" {
    var p = MockDisplayProvider.init(.{ .maxx = 50, .maxy = 50 });
    var d = p.provider();

    d.endwin();
    try std.testing.expectError(ZrogueError.NotInitialized, d.erase());
    try std.testing.expectError(ZrogueError.NotInitialized, d.getmaxx());
    try std.testing.expectError(ZrogueError.NotInitialized, d.getmaxy());
}

// Visualization

const genFields = @import("utils/visual.zig").genFields;
pub var display_fields = genFields(DisplayProvider);

// EOF
