//! Syntetica public API

const std = @import("std");
const sdl = @import("sdl3");
const Window = @import("Window.zig");
const ini = @import("init.zig");

pub const EngineConfig = struct {
    entity_list: ?[]const type = null,
};

pub fn init(title: [:0]const u8, flags: Window.WindowFlags) !void {
    try ini.initSDL();

    const disp = try sdl.video.Display.getPrimaryDisplay();

    const dm = try sdl.video.Display.getCurrentMode(disp);

    const win_size = if(flags.position == .windowed or flags.position == .centered) flags.size orelse global.Vec2u.vec2(@intCast(dm.width / 2), @intCast(dm.height / 2))
        else global.Vec2u.vec2(@intCast(dm.width), @intCast(dm.height));

    try ini.initWindow(title, win_size.x, win_size.y);
    try ini.initEntityManager();
}

pub fn isRunning() bool {
    return !global.Variable.engine_should_exit;
}

pub const global = @import("global.zig");

pub fn getSettings() *@TypeOf(global.Settings) {
    return &global.Settings;
}
pub fn getKeybinds() *@TypeOf(global.Keybinds) {
    return &global.Keybinds;
}

pub const Texture = @import("texManager.zig");
pub const Frame = @import("Frame.zig");

// wrapper for entity stuff for easier access.
pub const Entity = @import("Entity.zig").SyntApi;
