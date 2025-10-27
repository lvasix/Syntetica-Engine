const synt = @import("syntetica");

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
