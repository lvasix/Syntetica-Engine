const std = @import("std");
const global = @import("global.zig");
const rl = @import("raylib");

fn drawEntities() void {
    for (try global.Manager.entity.data.listIDs) |value| {
        _ = value;
    }
}

/// Rendering pass start
pub fn start() !void {
    const bg = global.Variable.background_color;
    global.Variable.engine_should_exit = rl.windowShouldClose();

    rl.clearBackground(.{.r = bg.r, .g = bg.g, .a = bg.a, .b = bg.b});
    rl.beginDrawing();
}

/// Logic update, end of frame
pub fn end() void {
    rl.endDrawing();

    // LOGIC UPDATE //////////// 
    global.Manager.entity.tick() catch |e| {
        std.debug.print("ERROR: {} => Failed ticking entities.", .{e});
    };
}
