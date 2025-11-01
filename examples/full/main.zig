const std = @import("std");
const synt = @import("syntetica");
//const sdl3 = @import("syntetica").sdl;

pub const _config = synt.EngineConfig{
    .entity_list = &@import("entites.zig").entity_list,
};

//const ActorStyle = @import("eng/ActorStyle.zig");

pub fn main() !void {
    try synt.init("Hello syntetica!!", .{});

    _ = try synt.Entity.spawn(.Player, .val(0, 0));
    for(0..10) |_| _ = try synt.Entity.spawn(.Enemy, .val(0, 0));
    try synt.Entity.killAll(.Enemy);

    var psim: synt.Physics.Manager = try.init(synt.global.Variable.allocator);
    const id = try psim.addBody(.{
        .pos = .val(0, 0),
        .collider = .{ .circle = .val(2) },
        .force = .val(20, 30),
        .mobility = .rigid,
    });
    const body = psim.bodies.getPtr(id);

    std.debug.print("BODY1: {}\n", .{psim.bodies.get(id).pos});

    var body_shape = synt.Shapes.square(body.pos, 20);
    const wall = synt.Shapes.rect(.val(100, 100), 20, 40);

    synt.rl.setTargetFPS(30);
    while(synt.isRunning()){
        body_shape.reshape(synt.Shapes.square(body.pos, 20));

        if (synt.rl.isKeyDown(.w)) {
            body.force.add(.val(0, -2));
        } if (synt.rl.isKeyDown(.s)) {
            body.force.add(.val(0, 2));
        } if (synt.rl.isKeyDown(.a)) {
            body.force.add(.val(-2, 0));
        } if (synt.rl.isKeyDown(.d)) {
            body.force.add(.val(2, 0));
        }
        body.force.clamp(20);

        try psim.tick();

        // render
        try synt.Frame.start();
        defer synt.Frame.end();

        synt.rl.drawRectangle(100, 100, 20, 40, if(body_shape.overlaps(wall)) .red else .white);
        synt.rl.drawRectangle(@intFromFloat(body.pos.x), @intFromFloat(body.pos.y), 20, 20, .white);


        synt.rl.drawLineEx( 
            .init(body.pos.x + 10, body.pos.y + 10), 
            .init(body.pos.x + 10 + body.force.x*2, body.pos.y + 10 + body.force.y*2), 
            3.0, 
            .red,
        );
    }

    const shape1 = synt.Shapes.square(.val(2, 2), 4);
    const shape2 = synt.Shapes.rect(.val(2, 5), 2, 4);
    std.debug.print("SHAPE: {}\n", .{shape1.overlaps(shape2)});
}
