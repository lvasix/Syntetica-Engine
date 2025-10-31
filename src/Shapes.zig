pub const Square = struct {
    a: u64,

    pub fn val(a: u64) Square {
        return .{.a = a};
    }
};

pub const Circle = struct {
    radius: u64,

    pub fn val(radius: u64) Circle {
        return .{.radius = radius};
    }
};

pub const Rect = struct {
    a: u64,
    b: u64,

    pub fn val(a: u64, b: u64) Rect {
        return .{.a = a, .b = b};
    }
};
