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

// TODO not sure if there's a more elegant approach
const GameState = enum {
    run,
    end,
};

// Return value from ActionGameHandler

const ActionResult = enum {
    continue_game, // Game still in progress
    end_game, // Quit, death, etc.
    ascend,
    descend,
};

//
// Game loop
//

pub fn run(s_config: new_level.LevelConfig) !void {
    var config = s_config; // force to internal var
    var player_thing = config.player.?;
    player_thing.addMessage("Welcome to the dungeon!");

    // TODO: master copy of the map versus player copy

    var state: GameState = .run;
    while (state != .end) {
        var map = try new_level.createLevel(config);
        defer map.deinit();

        var result: ActionResult = .continue_game;
        while (result == .continue_game) {
            var action = try player_thing.getAction(map);
            // TODO: actFn a field in action, callback to player or Thing?
            const actFn: ActionGameHandler = switch (action.kind) {
                .ascend => ascendAction,
                .descend => descendAction,
                .move => moveAction,
                .take => takeAction,
                .quit => quitAction,
                .none => doNothingAction,
                .wait => doNothingAction, // TODO meh untrue
            };

            result = try actFn(player_thing, &action, map);
            switch (result) {
                .continue_game => {}, // Does nothing
                .end_game => {
                    state = .end;
                },
                .descend => {
                    config.level += 1;
                    if (config.level > 3) {
                        config.going_down = false;
                    }
                },
                .ascend => {
                    config.level -= 1;
                    if (config.level < 1) {
                        state = .end;
                    }
                },
            }
        } // Playing loop
    } // Game ends

    // TODO 0.1 : level == 0 game endings

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
    // TODO 0.2 - smarten this
    const p = entity.getPos();
    const tile = try map.getOnlyTile(p.getX(), p.getY());
    if (tile == .stairs_up) {
        entity.addMessage("You ascend closer to the exit...");
        return ActionResult.ascend;
    }

    entity.addMessage("I see no way up");
    return ActionResult.continue_game;
}

fn descendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    // TODO 0.2 - smarten this
    const p = entity.getPos();
    const tile = try map.getOnlyTile(p.getX(), p.getY());
    if (tile == .stairs_down) {
        entity.addMessage("You go ever deeper into the dungeon...");
        return ActionResult.descend;
    }

    entity.addMessage("I see no way down");
    return ActionResult.continue_game;
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
