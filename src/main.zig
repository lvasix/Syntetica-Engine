const std = @import("std");
const synt = @import("syntetica");

pub const _config = synt.EngineConfig{
    .entity_list = &@import("entites.zig").entity_list,
};

pub fn main() !void {
    try synt.init("Hello syntetica!!", .{});

    _ = try synt.Entity.spawn(.Player);
    
    for(0..10) |_| _ = try synt.Entity.spawn(.Enemy);

    try synt.Entity.killAll(.Enemy);

    while(synt.isRunning()){
        // logic

        try synt.Frame.start();
        defer synt.Frame.end();
        
        // render
    }
}
