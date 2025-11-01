const global = @import("global.zig");

pub const Segment = struct {
    a: global.Vec2,
    b: global.Vec2,
};

pub const Axis = global.Vec2;

pub fn dotProduct(p1: global.Vec2, p2: global.Vec2) f32 {
    return p1.x * p2.x + p1.y * p2.y;
}

pub fn addValueWrap(val1: anytype, val2: anytype, size: isize) @TypeOf(val1) {
    const i = val1 + val2;
    return @mod(@mod(i, size) + size, size);
}

pub fn subValueWrap(val1: anytype, val2: anytype, size: isize) @TypeOf(val1) {
    const i = val1 - val2;
    return @mod(@mod(i, size) + size, size);
}
