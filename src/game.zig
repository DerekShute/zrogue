const std = @import("std");
const zrogue = @import("zrogue.zig");
const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;

const Map = @import("map.zig").Map;
const Room = @import("map.zig").Room;

const Thing = @import("thing.zig").Thing;

//
// Game loop
//

pub fn run(allocator: std.mem.Allocator, player_thing: *Thing) !void {
    var map: Map = try Map.config(allocator, zrogue.MAPSIZE_X, zrogue.MAPSIZE_Y, zrogue.ROOMS_X, zrogue.ROOMS_Y);
    defer map.deinit();

    try map.setMonster(player_thing, 6, 6);

    var room = try Room.config(Pos.init(2, 2), Pos.init(9, 9));
    room.setDark();
    try map.addRoom(room);

    try map.addRoom(try Room.config(Pos.init(27, 5), Pos.init(35, 10)));
    try map.dig(Pos.init(9, 5), Pos.init(27, 8));

    try map.addRoom(try Room.config(Pos.init(4, 12), Pos.init(20, 19)));
    try map.dig(Pos.init(4, 9), Pos.init(18, 12));

    player_thing.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy
    var action = ThingAction.init(ActionType.NoAction);
    while (action.type != ActionType.QuitAction) {
        action = try player_thing.doAction(&map);
        switch (action.type) {
            ActionType.QuitAction => continue, // TODO: 'quitting' message
            ActionType.AscendAction => try ascendAction(player_thing, &action, &map),
            ActionType.DescendAction => try descendAction(player_thing, &action, &map),
            ActionType.MoveAction => try moveAction(player_thing, &action, &map),
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

fn descendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    _ = do_action;
    _ = map;
    entity.addMessage("No stairs here!");
}

fn moveAction(entity: *Thing, do_action: *ThingAction, map: *Map) !void {
    const pos = entity.getPos();
    const newPos = do_action.getPos();

    const new_x = pos.getX() + newPos.getX();
    const new_y = pos.getY() + newPos.getY();

    if (try map.passable(new_x, new_y)) {
        try map.removeMonster(pos.getX(), pos.getY());
        try map.setMonster(entity, new_x, new_y);

        // TODO if not blind
        try map.setRegionKnown(new_x - 1, new_y - 1, new_x + 1, new_y + 1);
        try map.revealRoom(entity.getPos());
    } else {
        // TODO: entity 'bump' callback
        entity.addMessage("Ouch!");
    }
}

// EOF
