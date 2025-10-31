//! Syntetica public API

const std = @import("std");
pub const rl = @import("raylib");
const Window = @import("Window.zig");
const ini = @import("init.zig");

pub const EngineConfig = struct {
    entity_list: ?[]const type = null,
};

pub fn init(title: [:0]const u8, flags: Window.WindowFlags) !void {
    _ = flags;
    ini.initWindow(title, 1200, 800);
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
pub const Physics = @import("Physics.zig");

// wrapper for entity stuff for easier access.
pub const Entity = @import("Entity.zig").SyntApi;
