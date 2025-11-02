const std = @import("std");
const rl = @import("raylib");
const Texture = @This();
const global = @import("global.zig");

pub const Options = struct {
    pub const TextureType = enum {
        tile,
        entity,
        ui,
        none,
    };

    render_opaque: bool = false,
    texture_type: TextureType = .none,

    pub fn setType(T: TextureType) Options {
        return .{.texture_type = T};
    }
};

pub const Meta = struct {
    name: [:0]const u8,
    path: []const u8,
    opt: Options = .{},

    pub fn tex(
        comptime name: [:0]const u8, 
        comptime path: []const u8, 
        comptime options: Options
    ) Meta {
        return .{
            .name = name,
            .path = path,
            .opt = options,
        };
    }
};

pub fn Manager(comptime tex_meta: []const Meta) type {
    var texture_fields: [tex_meta.len + 1]std.builtin.Type.EnumField = undefined;

    inline for(tex_meta, 0..) |meta, i| {
        texture_fields[i] = .{
            .name = meta.name,
            .value = i,
        };
    }

    texture_fields[tex_meta.len] = .{.name = "undef", .value = tex_meta.len};

    const generated_texture_enum: type = @Type(.{.@"enum" = .{
        .decls = &.{},
        .tag_type = u32,
        .fields = &texture_fields,
        .is_exhaustive = false,
    }});

    return struct {
        const SelfManager = @This();
        pub const TextureEnum = generated_texture_enum;

        loaded_textures: [tex_meta.len + 1]bool = [1]bool{false} ** (tex_meta.len + 1),
        tex_arr: [tex_meta.len + 1]Texture = undefined,

        pub fn init() SelfManager {
            return .{};
        }

        pub fn getTex(self: *SelfManager, tex: TextureEnum) !Texture {
            const index = @intFromEnum(tex);

            const tex_path = try std.fmt.allocPrintSentinel(global.Variable.allocator, "{s}res/{s}", .{rl.getApplicationDirectory(), tex_meta[index].path}, 0);

            std.debug.print("PATH: {s}", .{tex_path});

            // checks if the requested texture is loaded into GPU memory and loads it if not.
            if(!self.loaded_textures[index]) {
                self.tex_arr[index].rl_texture = try rl.Texture.init(@as([:0]u8, tex_path));
                self.loaded_textures[index] = true;
            }

            return self.tex_arr[index];
        }
    };
}

rl_texture: rl.Texture = undefined,
