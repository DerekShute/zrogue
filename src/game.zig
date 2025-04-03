const std = @import("std");
const zrogue = @import("zrogue.zig");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const Room = @import("map.zig").Room;
const Thing = @import("thing.zig").Thing;

const new_level = @import("new_level.zig");

const ThingAction = zrogue.ThingAction;
const ActionType = zrogue.ActionType;
const Pos = zrogue.Pos;
const ZrogueError = zrogue.ZrogueError;

// Return value from ActionGameHandler

const ActionResult = enum {
    continue_game, // Game still in progress
    end_game, // Quit, death, etc.
};

//
// Game loop
//

pub fn run(config: new_level.LevelConfig) !void {
    var player_thing = config.player.?;
    player_thing.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy

    var result: ActionResult = .continue_game;
    while (result != .end_game) {
        var map = try new_level.createLevel(config);
        defer map.deinit();

        var action = ThingAction.init(ActionType.NoAction);
        while (action.kind != ActionType.QuitAction) {
            action = try player_thing.getAction(map);
            // TODO: actFn a field in action, callback to player or Thing?
            const actFn: ActionGameHandler = switch (action.kind) {
                .AscendAction => ascendAction,
                .DescendAction => descendAction,
                .MoveAction => moveAction,
                .TakeAction => takeAction,
                .QuitAction => quitAction,
                .NoAction => doNothingAction,
            };
            result = try actFn(player_thing, &action, map);
            if (result == .end_game) {
                break;
            }
        }
    }
}

//
// Action development here
//

const ActionGameHandler = *const fn (self: *Thing, do_action: *ThingAction, map: *Map) ZrogueError!ActionResult;

fn doNothingAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    _ = map;
    _ = entity;

    return ActionResult.continue_game;
}

fn ascendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    _ = map;
    entity.addMessage("No stairs here!");

    return ActionResult.continue_game; // TODO: for now
}

fn descendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    _ = map;
    entity.addMessage("No stairs here!");

    // TODO: map.getTile returns what is visible: the player, not the stairs

    return ActionResult.continue_game; // TODO: for now
}

fn moveAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
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

    return ActionResult.continue_game;
}

fn quitAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    _ = map;
    _ = entity;

    // TODO: save?

    return ActionResult.end_game;
}

fn takeAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    const item = map.getItem(do_action.getPos());
    if (item) |i| {
        entity.takeItem(i, map);
    } else {
        entity.addMessage("Nothing here to take!");
    }

    return ActionResult.continue_game;
}

// EOF
