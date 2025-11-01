const global = @import("global.zig");
const rl = @import("raylib");
const math = @import("math.zig");
const std = @import("std");

pub const Square = struct {
    pos: global.Vec2 = .val(0, 0),
    a: u64 = 0,
    angle: f64 = 0.0,

    pub fn val(a: u64) Square {
        return .{.a = a};
    }
};

pub const Circle = struct {
    pos: global.Vec2 = .val(0, 0),
    radius: u64 = 0,

    pub fn val(radius: u64) Circle {
        return .{.radius = radius};
    }
};

pub const Rect = struct {
    pos: global.Vec2 = .val(0, 0),
    a: u64 = 0,
    b: u64 = 0,
    angle: f64 = 0.0,

    pub fn val(a: u64, b: u64) Rect {
        return .{.a = a, .b = b};
    }
};

pub const Edge = struct {
    start: global.Vec2,
    end: global.Vec2,

    pub fn init(start: global.Vec2, end: global.Vec2) Edge {
        return .{.start = start, .end = end};
    }

    pub fn getNormal(self: Edge) global.Vec2 {
        return .val(-(self.end.y - self.start.y), self.end.x - self.start.x);
    }
};

pub const Projection = struct {
    min: f32 = 0,
    max: f32 = 0,

    pub fn init(min: f32, max: f32) Projection {
        return .{.min = min, .max = max};
    }

    pub fn overlaps(self: Projection, projB: Projection) bool {
        return !(self.max < projB.min or projB.max < self.min);
    }
};

// A------D
// |      |
// |      |
// B------C
pub fn Polygon(vert_amount: usize) type {
    return struct {
        const Self = @This();
        vertecies: [vert_amount]global.Vec2 = [1]global.Vec2{.val(0,0)} ** vert_amount,

        pub fn init(vert: [vert_amount]global.Vec2) Self {
            return .{
                .vertecies = vert,
            };
        }

        pub fn project(self: Self, axis: math.Axis) Projection {
            var minProj: f32 = std.math.inf(f32);
            var maxProj: f32 = -std.math.inf(f32);

            for(self.vertecies) |vertex| {
                const proj = math.dotProduct(vertex, axis);
                minProj = @min(minProj, proj);
                maxProj = @max(maxProj, proj);
            }

            return .init(minProj, maxProj);
        }

        pub fn overlaps(self: Self, shape: anytype) bool {
            comptime if(!@hasField(@TypeOf(shape), "vertecies")) @compileError("Cannot check overlap with non-shape container.");

            for(self.vertecies, 0..) |vertex, i| {
                const index = math.subValueWrap(
                    @as(i64, @intCast(i)), 1, self.vertecies.len);
                
                const edge = Edge.init(vertex, self.vertecies[@intCast(index)]);

                const normal = edge.getNormal();

                const projA = self.project(normal);
                const projB = shape.project(normal);

                if(!projA.overlaps(projB)){
                    return false;
                }
            }

            for(shape.vertecies, 0..) |vertex, i| {
                const index = math.subValueWrap(@as(i64, @intCast(i)), 1, shape.vertecies.len);
                
                const edge = Edge.init(vertex, shape.vertecies[@intCast(index)]);

                const normal = edge.getNormal();

                const projA = self.project(normal);
                const projB = shape.project(normal);

                if(!projA.overlaps(projB)){
                    return false;
                }
            }

            return true;
        }

        pub fn reshape(self: *Self, new: Self) void {
            self.* = new;
        }
    };
}

pub fn square(pos: global.Vec2, a: f32) Polygon(4) {
    return .init(.{
        .val(pos.x, pos.y),
        .val(pos.x + a, pos.y),
        .val(pos.x + a, pos.y + a),
        .val(pos.x, pos.y + a),
    });
}

pub fn rect(pos: global.Vec2, w: f32, h: f32) Polygon(4) {
    return .init(.{
        .val(pos.x, pos.y),
        .val(pos.x, pos.y + h),
        .val(pos.x + w, pos.y + h),
        .val(pos.x + w, pos.y),
    });
}
