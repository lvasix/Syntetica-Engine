const std = @import("std");
const global = @import("global.zig");
const FreeList = @import("FreeList.zig");
const Shapes = @import("Shapes.zig");

const Body = struct {
    const Mobility = enum {
        rigid,
        static,
        part,
    };

    const Collider = union(enum) {
        circle: Shapes.Circle,
        square: Shapes.Square,
        rect: Shapes.Rect,
        compound: []Collider,
    };

    mobility: Mobility = .rigid,
    pos: global.Vec2 = .val(0, 0),
    collider: Collider = .{ .square = .val(3) },
    force: global.Vec2 = .val(0, 0),
    friction: f32 = 1.0,
};

pub const Manager = struct {
    bodies: FreeList.SimpleLinkedFreeList(Body, global.alloc_size) = undefined,

    allocator: std.mem.Allocator,
    physics_tick: usize = 0,

    /// object which is used as the simulation distance reference, it defines how 
    /// far from it the bodies are simulated.
    simulation_obj: ?usize = 0,
    friction: f32 = 1.0,

    pub fn init(alloc: std.mem.Allocator) !Manager {
        const obj = Manager{
            .bodies = try .init(alloc),
            .allocator = alloc,
            .physics_tick = 0,
        };

        return obj;
    }

    pub fn addBody(self: *Manager, body: Body) !usize {
        const id = try self.bodies.insert(body);

        return id;
    }

    pub fn rmBody(self: *Manager, bID: usize) void {
        self.bodies.deleteID(bID);
    }

    pub fn tick(self: *Manager) !void {
        for (try self.bodies.listIDs()) |bid| {
            const body = self.bodies.getPtr(bid);

            body.pos.add(body.force);

            body.force.subMagnitude(body.friction);
        }
    }
};
