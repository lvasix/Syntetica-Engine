//! Global variables, states and settings for Syntetica engine
pub const Vec2i = @import("Vec2.zig").Vec2(i32);
pub const Vec2u = @import("Vec2.zig").Vec2(u32);
pub const Vec2 = @import("Vec2.zig").Vec2(f32);

const std = @import("std");
const sdl = @import("sdl3");
const Color = @import("Color.zig");
const Tile = @import("tile.zig");
const Entity = @import("Entity.zig");
const main = @import("root");
const chunk_size: comptime_int = 16;

pub const Tilemap = @import("Tilemap.zig").Tilemap(Tile, chunk_size);

/// global settings for Syntetica engine
pub var Setting: struct {
    screen_size: Vec2u = .vec2(0, 0),
    fps_cap: usize = 60,
} = .{};

/// global variables for Syntetica engine.
pub var Variable: struct {
    // SDL3 ////////////////////
    sdl_init_flags: sdl.InitFlags = undefined,
    sdl_default_window: sdl.video.Window = undefined,
    sdl_window_surface: sdl.surface.Surface = undefined,
    sdl_fps_capper: sdl.extras.FramerateCapper(f32) = undefined,

    // graphics ////////////////
    background_color: Color = .rgb(0, 0, 0),

    // engine //////////////////
    engine_should_exit: bool = false,
    delta_time: f32 = 0,
    allocator: std.mem.Allocator = std.heap.page_allocator,
} = .{};

/// global process's and manager's types for Syntetica engine.
pub var Manager: struct {
    entity: Entity.Manager(main._config.entity_list) = undefined,
} = .{};

/// Keybinds for Syntetica engine
pub var Keybind: struct {
    /// keybind for closing the main app. if null, no keybind is used and it is up to the 
    /// app to handle closing.
    close_app: ?sdl.keycode.Keycode = .q,
} = .{};
