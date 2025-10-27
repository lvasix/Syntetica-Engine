//! Initializer functions for Syntetica

const std = @import("std");
const sdl = @import("sdl3");
const global = @import("global.zig");

pub fn initTaskManager() !void {

}

pub fn initSDL() !void {
    global.Variable.sdl_init_flags = sdl.InitFlags{ .video = true };
    try sdl.init(global.Variable.sdl_init_flags);
}

pub fn initWindow(title: [:0]const u8, w: usize, h: usize) !void {
    global.Variable.sdl_default_window = 
        try sdl.video.Window.init(title, w, h, .{});

    global.Variable.sdl_fps_capper = 
        sdl.extras.FramerateCapper(f32){ .mode = .{ .limited = global.Setting.fps_cap } };
}

pub fn initEntityManager() !void {
    global.Manager.entity = try @TypeOf(global.Manager.entity).init(global.Variable.allocator);
}

pub fn close() void {
    global.Variable.sdl_default_window.deinit();
    sdl.quit(global.Variable.init_flags);
}
