const std = @import("std");

pub fn PhVec(T: type) type {
    return struct {
        const rad = T;
        const Self = @This();

        direction: rad,
        magnitute: T,

        pub fn val(dir: rad, magn: T) Self {
            return .{.direction = dir, .magnitute = magn};
        }

        pub fn toCaVec(self: Self) Vec2(T) {
            const y = @sin(self.direction) * self.magnitute;
            const x = @sqrt(self.magnitute * self.magnitute - y * y);

            std.debug.print("X: sin({}) * {} = {}\n", .{self.direction, self.magnitute, x});
            std.debug.print("Y: {}\n", .{y});

            return .val(x, y);
        }
    };
}

pub fn Vec2(T: type) type {
    return struct {
        x: T,
        y: T,

        const Self = @This();

        pub fn val(x: T, y: T) Self {
            return .{.x = x, .y = y};
        }

        pub fn dist(self: Self, b: @TypeOf(Self)) f64 {
            const A = @Vector(2, T){self.x, self.y};
            const B = @Vector(2, T){b.x, b.y};

            const part1 = (A.@"0" - B.@"0") * (A.@"0" - B.@"0");
            const part2 = (A.@"1" - B.@"1") * (A.@"0" - B.@"0");

            return @sqrt(part1 + part2);
        }

        pub fn add(self: *Self, b: Self) void {
            self.x += b.x; 
            self.y += b.y;
        }

        pub fn sub(self: *Self, b: Self) void {
            self.x -= b.x;
            self.y -= b.y;
        }

        pub fn toPhVec(self: Self) PhVec(T) {
            const magnitute: T = @sqrt(self.x * self.x + self.y * self.y);
            std.debug.print("MAGN: {}", .{magnitute});
            
            const dir = std.math.asin(self.y / magnitute);

            std.debug.print("ASIN: asin({}/{}) = {}\n", .{self.y, magnitute, std.math.asin(self.y / magnitute)});
            std.debug.print("NEW VECTOR: {} {}\n", .{magnitute, dir});

            return .{.magnitute = magnitute, .direction = dir};
        }

        pub fn addMagnitude(self: *Self, f: T) void {
            // if we have a 0 vector, we don't know in which 
            // direction to add the magnitude.
            if(self.x == 0 and self.y == 0) return;

            // m - magnitude 
            // m1 - new magnitude 
            // U - unit vector 
            // V - resulting vector 
            const m = @sqrt(self.x * self.x + self.y * self.y);

            // this is the part that adds the actual magnitude, the output 
            // is then clamped so it doesn't go below 0
            const m1 = @max(0, m + f);
            const U: Self = .val(self.x / m, self.y / m);

            // this step will flip the signs of the values if needed.
            const V: Self = .val(U.x * m1, U.y * m1);

            self.* = V;
        } 

        pub fn getMagnitude(self: *Self) T {
            return @sqrt(self.x * self.x + self.y * self.y);
        }

        pub fn setMagnitude(self: *Self, m: T) void {
            if(self.x == 0 and self.y == 0) return;

            const vec_m = self.getMagnitude();

            const U: Self = .val(self.x / vec_m, self.y / vec_m);

            // this step will flip the signs of the values if needed.
            const V: Self = .val(U.x * m, U.y * m);

            self.* = V;
        }

        pub fn subMagnitude(self: *Self, f: T) void {
            self.addMagnitude(-f);
        }

        pub fn clamp(self: *Self, v: T) void {
            if(self.getMagnitude() < v) return;
            self.setMagnitude(v);
        }
    };
}

pub fn vec2(x: anytype, y: @TypeOf(x)) Vec2(@TypeOf(x)) {
    return Vec2(@TypeOf(x)).val(x, y);
}
