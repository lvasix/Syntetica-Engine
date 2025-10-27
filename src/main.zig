const std = @import("std");
const synt = @import("syntetica");

// TEXTURES //////////////////
const textures = struct {
    pub const def = enum {
        air,
        undef,
        _ENDREG,
    };

    pub const path = [_][]const u8 {
        "none",
        "test/path",
    };

    pub const meta = [_]synt.Texture.MetaData{
        .{
            .render = false,
        },
        .{
            .has_transparency = true,
        },
    };
};
///////////////////////////////

pub fn main() !void {
    var ent_reg: @import("entites.zig").GetManager() = try .init(std.heap.page_allocator);
    defer ent_reg.release();
//    ent_reg.ent_enum = .player;

    const player: usize = try ent_reg.spawn(.Player);
    const enemy1: usize = try ent_reg.spawn(.Enemy);
    const enemy2: usize = try ent_reg.spawn(.Enemy);
    const enemy3: usize = try ent_reg.spawn(.Enemy);

    _ = enemy2;
    _ = enemy3;

    try ent_reg.tick();
    try ent_reg.tick();

    ent_reg.kill(player);
    ent_reg.kill(enemy1);

    try synt.init("Hello syntetica!!", .{});
    while(synt.isRunning()){
        // logic

        try synt.Frame.start();
        defer synt.Frame.end();
        
        // render
    }
}
