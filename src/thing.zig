const std = @import("std");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const zrogue = @import("zrogue.zig");

const ZrogueError = zrogue.ZrogueError;
const ThingAction = zrogue.ThingAction;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;

// ===================
//
// Structure for monsters and player
//
pub const Thing = struct {
    // TODO Future: timer, action queue
    p: Pos = undefined,
    tile: MapTile = undefined,
    vtable: *const VTable = undefined,
    moves: i32 = 0,

    pub const VTable = struct {
        addMessage: ?*const fn (self: *Thing, msg: []const u8) void,
        getAction: *const fn (self: *Thing, map: *Map) ZrogueError!ThingAction,
        takeItem: ?*const fn (self: *Thing, item: *Item, map: *Map) void,
    };

    pub fn config(tile: MapTile, vtable: *const Thing.VTable) Thing {
        return Thing{
            .p = Pos.init(-1, -1),
            .tile = tile,
            .vtable = vtable,
        };
    }

    pub fn getTile(self: *Thing) MapTile {
        return self.tile;
    }

    // VTable

    pub fn addMessage(self: *Thing, msg: []const u8) void {
        if (self.vtable.addMessage) |cb| {
            cb(self, msg);
        }
    }

    pub fn getAction(self: *Thing, map: *Map) ZrogueError!ThingAction {
        return try self.vtable.getAction(self, map);
    }

    pub fn search(self: *Thing, map: *Map) void {
        if (self.vtable.search) |cb| {
            cb(self, map);
        }
    }

    pub fn takeItem(self: *Thing, item: *Item, map: *Map) void {
        if (self.vtable.takeItem) |cb| {
            cb(self, item, map);
        }
    }

    pub fn getMoves(self: *Thing) i32 {
        return self.moves;
    }

    pub usingnamespace Pos.Methods(@This());
};

// Unit Tests

// TODO: need a mock version

// Visualization

const genFields = @import("utils/visual.zig").genFields;

pub var thing_fields = genFields(Thing);

// EOF
