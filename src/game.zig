const std = @import("std");
const zrogue = @import("zrogue.zig");
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const MapContents = zrogue.MapContents;

const Map = @import("map.zig").Map;
const Room = @import("map.zig").Room;

const Thing = @import("thing.zig").Thing;

//
// Game loop
//

pub fn run(allocator: std.mem.Allocator, player_thing: *Thing) !void {
    var map: Map = try Map.config(allocator, zrogue.MAPSIZE_Y, zrogue.MAPSIZE_X);
    defer map.deinit();

    try map.setMonster(player_thing, 10, 10);

    var room = Room.config(Pos.init(5, 5), Pos.init(15, 15));
    room.setDark();
    try map.addRoom(room);

    player_thing.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy
    var action = ThingAction.init(ActionType.NoAction);
    while (action.type != ActionType.QuitAction) {
        action = try player_thing.doAction(&map);
        switch (action.type) {
            ActionType.QuitAction => continue, // TODO: 'quitting' message
            ActionType.BumpAction => try bumpAction(player_thing, &action, &map),
            ActionType.AscendAction => try ascendAction(player_thing, &action, &map),
            ActionType.DescendAction => try descendAction(player_thing, &action, &map),
            ActionType.NoAction => continue,
        }
    }
}

//
// Action development here
//

fn ascendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    _ = do_action;
    _ = map;
    entity.addMessage("No stairs here!");
}

fn bumpAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    const pos = entity.getPos();

    // TODO Law of Demeter here
    const new_x = pos.getX() + do_action.pos.getX();
    const new_y = pos.getY() + do_action.pos.getY();

    if (try map.passable(new_x, new_y)) {
        try map.removeMonster(pos.getX(), pos.getY());
        try map.setMonster(entity, new_x, new_y);

        // TODO map edges
        // TODO if not blind
        if ((map.inRoom(entity.getPos())) and (map.isLit(entity.getPos()))) {
            // TODO how to do only once?
            try map.setRegionKnown(map.room.getMinX(), map.room.getMinY(), map.room.getMaxX(), map.room.getMaxY());
        } else {
            try map.setRegionKnown(new_x - 1, new_y - 1, new_x + 1, new_y + 1);
        }
    } else {
        entity.addMessage("Ouch!");
    }
}

fn descendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    _ = do_action;
    _ = map;
    entity.addMessage("No stairs here!");
}

// EOF
