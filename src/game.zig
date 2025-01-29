const std = @import("std");
const zrogue = @import("zrogue.zig");
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const MapContents = zrogue.MapContents;

const Map = @import("level.zig").Map;

const Thing = @import("thing.zig").Thing;

//
// Game loop
//

pub fn run(allocator: std.mem.Allocator, player_thing: *Thing) !void {
    const map = try Map.init(allocator, zrogue.MAPSIZE_Y, zrogue.MAPSIZE_X);
    defer map.deinit();

    try map.setMonster(player_thing, 10, 10);

    try map.drawRoom(5, 5, 15, 15);
    player_thing.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy
    var action = ThingAction.init(ActionType.NoAction);
    while (action.type != ActionType.QuitAction) {
        action = try player_thing.doAction(map);
        switch (action.type) {
            ActionType.QuitAction => continue, // TODO: 'quitting' message
            ActionType.BumpAction => try bumpAction(player_thing, &action, map),
            ActionType.NoAction => continue,
        }
    }
}

//
// Action development here
//

fn bumpAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    const pos = entity.getPos();

    // TODO Law of Demeter here
    const new_x = pos.getX() + do_action.pos.getX();
    const new_y = pos.getY() + do_action.pos.getY();

    // TODO: 'passable'
    if (try map.getChar(new_x, new_y) == MapContents.floor) {
        try map.removeMonster(pos.getX(), pos.getY());
        try map.setMonster(entity, new_x, new_y);
        // TODO reveal surroundings if dark and not blind
    } else {
        entity.addMessage("Ouch!");
    }
}

// EOF
