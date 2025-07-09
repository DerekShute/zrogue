//!
//! Playing the game
//!
//! Simple state machine for deciding if a game is happening
//!

const std = @import("std");
const zrogue = @import("zrogue.zig");
const Feature = @import("Feature.zig");
const Item = @import("item.zig").Item;
const Map = @import("map.zig").Map;
const Room = @import("map.zig").Room;
const Thing = @import("thing.zig").Thing;

const new_level = @import("new_level.zig");

const Region = zrogue.Region;
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

    var state: GameState = .run;
    while (state != .end) {
        var map = try new_level.createLevel(config);
        defer map.deinit();

        // Reset player map knowledge with new map
        const r = Region.config(Pos.init(0, 0), Pos.init(s_config.xSize - 1, s_config.ySize - 1));
        player_thing.setKnown(r, false);

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
                .search => searchAction,
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

    // TODO : level == 0 game endings

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
    if (try map.getFloorTile(entity.getPos()) == .stairs_up) {
        entity.addMessage("You ascend closer to the exit...");
        entity.moves += 10;
        return ActionResult.ascend;
    }

    entity.addMessage("I see no way up");
    return ActionResult.continue_game;
}

fn descendAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;
    if (try map.getFloorTile(entity.getPos()) == .stairs_down) {
        entity.addMessage("You go ever deeper into the dungeon...");
        entity.moves += 10;
        return ActionResult.descend;
    }

    entity.addMessage("I see no way down");
    return ActionResult.continue_game;
}

fn moveAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    const pos = entity.getPos();
    const new_pos = Pos.add(pos, do_action.getPos());

    if (!try map.passable(new_pos)) {
        // TODO: entity 'bump' callback
        entity.moves += 5; // That hurt
        entity.addMessage("Ouch!");
        return ActionResult.continue_game;
    }

    try entity.move(map, new_pos);
    entity.moves += 1;

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
    if (try map.getItem(do_action.getPos())) |i| {
        entity.takeItem(i, map);
        entity.moves += 10;
    } else {
        entity.addMessage("Nothing here to take!");
    }

    return ActionResult.continue_game;
}

// TODO Future: get chance of success from entity, resolve that
fn searchAction(entity: *Thing, do_action: *ThingAction, map: *Map) !ActionResult {
    _ = do_action;

    // TODO Future: This is clunky.  We want an iterator in one step.
    const min = Pos.init(entity.getX() - 1, entity.getY() - 1);
    const max = Pos.init(entity.getX() + 1, entity.getY() + 1);
    var r = Region.config(min, max);
    var i = r.iterator();
    var found: bool = false;
    while (i.next()) |pos| {
        if (try map.getFeature(pos)) |f| {
            found = f.find(map);
        }
    }

    if (found) {
        entity.addMessage("You find something!");
    } else {
        entity.addMessage("You find nothing!");
    }

    entity.moves += 100;
    return ActionResult.continue_game;
}

// EOF
