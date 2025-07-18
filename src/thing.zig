//!
//! Abstraction structure for monsters and player
//!
//! Mostly an artifact of the C rogue implementation, which conflates the
//! two (plus items?) for purposes of consolidating list management code.

const std = @import("std");
const Feature = @import("Feature.zig");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const zrogue = @import("zrogue.zig");

const ZrogueError = zrogue.ZrogueError;
const ThingAction = zrogue.ThingAction;
const MapTile = zrogue.MapTile;
const Pos = zrogue.Pos;
const Region = zrogue.Region;

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
    los: Region = undefined, // line of sight

    pub const VTable = struct {
        addMessage: ?*const fn (self: *Thing, msg: []const u8) void,
        getAction: *const fn (self: *Thing, map: *Map) ZrogueError!ThingAction,
        setKnown: ?*const fn (self: *Thing, r: Region, val: bool) void,
        takeItem: ?*const fn (self: *Thing, item: *Item, map: *Map) void,
    };

    pub fn config(tile: MapTile, vtable: *const Thing.VTable) Thing {
        return Thing{
            .p = Pos.init(-1, -1),
            .tile = tile,
            .vtable = vtable,
            .los = Region.config(Pos.init(0, 0), Pos.init(0, 0)), // TODO invalid
        };
    }

    pub fn getTile(self: *Thing) MapTile {
        return self.tile;
    }

    pub fn move(self: *Thing, map: *Map, new: Pos) !void {
        const old = self.getPos();
        if (old.getX() != -1) { // Initialization case
            try map.removeMonster(old);
        }
        self.setPos(new);
        // TODO: player callback?
        // TODO: if not blind
        map.reveal(self);
        try map.setMonster(self);
        // REFACTOR map method to bundle
        if (try map.getFeature(new)) |f| {
            f.enter(map, self);
        }
    }

    pub fn setVisible(self: *Thing, new: Region) void {
        self.los = new;
    }

    pub fn isVisible(self: *Thing, at: Pos) bool {
        return self.los.isInside(at);
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

    pub fn setKnown(self: *Thing, r: Region, val: bool) void {
        if (self.vtable.setKnown) |cb| {
            cb(self, r, val);
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
