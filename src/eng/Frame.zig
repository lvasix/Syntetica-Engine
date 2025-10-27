const std = @import("std");
const global = @import("global.zig");
const sdl = @import("sdl3");

fn drawEntities() void {

}

/// Rendering pass start
pub fn start() !void {
    const bg = global.Variable.background_color;

    global.Variable.delta_time = global.Variable.sdl_fps_capper.delay();
    
    global.Variable.sdl_window_surface = 
        try global.Variable.sdl_default_window.getSurface();
    try global.Variable.sdl_window_surface.fillRect(
        null, global.Variable.sdl_window_surface.mapRgb(bg.r, bg.g, bg.b)
    );
    try global.Variable.sdl_default_window.updateSurface();
}

/// Logic update, end of frame
pub fn end() void {
    while (sdl.events.poll()) |event| switch (event) {
        .quit => global.Variable.engine_should_exit = true,
        .terminating => global.Variable.engine_should_exit = true,
        .key_down => |key| {
            if(global.Keybind.close_app != null and key.key.? == global.Keybind.close_app.?) 
                global.Variable.engine_should_exit = true;
        },
        else => {},
    };

    // LOGIC UPDATE //////////// 
    global.Manager.entity.tick() catch |e| {
        std.debug.print("ERROR: {} => Failed ticking entities.", .{e});
    };
}
