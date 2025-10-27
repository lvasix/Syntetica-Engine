//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const Vec2 = @import("Vec2.zig").Vec2(f64);
const Vec2u = @import("Vec2.zig").Vec2(u64);
const Vec2i = @import("Vec2.zig").Vec2(i64);
const Chunk = @import("Chunk.zig").Chunk;

const tmerr = error{
    chunk_nonexistant,
};

/// returns a Tilemap structure
pub fn Tilemap(TileType: type, chunk_size: i64) type {
    return struct {
        const Self = @This();
        const TilemapChunk = Chunk(TileType, chunk_size);
        const Pos = Vec2i;

        alloc: std.mem.Allocator,
        origin: Pos = .vec2(0, 0),
        data: std.AutoHashMap(
            Pos,
            TilemapChunk
        ),

        /// initializes the tilemap with a set allocator
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .alloc = allocator,  
                .data = .init(allocator)
            };
        }

        /// registers and adds a chunk into the tilemap
        pub fn addChunk(self: *Self, c: TilemapChunk) !void {
            try self.data.put(c.pos, c);
        }

        /// Does necessary calculations on the recieved position and returns the hashmap key
        fn getHashmapKey(pos: Pos) Pos {
            const x_rounded_pos: f64 = @floatFromInt(@divFloor(pos.x, chunk_size));
            const y_rounded_pos: f64 = @floatFromInt(@divFloor(pos.y, chunk_size));
            
            return .{ 
                .x = @intFromFloat( x_rounded_pos * @as(f64, @floatFromInt(chunk_size)) ),
                .y = @intFromFloat( y_rounded_pos * @as(f64, @floatFromInt(chunk_size)) )
            };
        }

        /// Does necessary calculations on recieved position and returns the offset into chunk data array
        fn getChunkOffset(pos: Pos, hmap_key: Pos) Vec2u {
            return .{
                .x = @intCast(pos.x - hmap_key.x),
                .y = @intCast(pos.y - hmap_key.y)
            };
        }

        /// Modifies a specific position on the tilemap
        pub fn modify(self: *Self, pos: Pos, tile: TileType) !void {
            const key: Pos = getHashmapKey(pos);
            const chunk_offset: Vec2u = getChunkOffset(pos, key);

            // get a pointer to our tile and directly modify the tile
            var chunk: *TilemapChunk = self.data.getPtr(key) orelse return error.chunk_nonexistant;
            try chunk.set(chunk_offset, tile);
        }

        /// returns a tile on pos. Returns error if the requested tile is in 
        /// a chunk that is not initialized/registered
        pub fn get(self: *Self, pos: Pos) !TileType {
            const key: Pos = getHashmapKey(pos);
            const chunk_offset: Vec2u = getChunkOffset(pos, key);

            var chunk: TilemapChunk = self.data.get(key) orelse return error.chunk_nonexistant;
            return try chunk.get(chunk_offset);
        }

        /// Returns a chunk at pos, the passed position can be anywhere in the chunk
        pub fn getChunk(self: *Self, pos: Pos) !TilemapChunk {
            const key: Pos = getHashmapKey(pos);
            return self.data.get(key) orelse return error.chunk_nonexistant;
        }

        /// Returns a pointer to the chunk at pos. The passed position can be anywhere in the chunk
        pub fn getChunkPtr(self: *Self, pos: Pos) !*TilemapChunk {
            const key: Pos = getHashmapKey(pos);
            return self.data.getPtr(key);
        }

        /// De-allocates Tilemap and cleans up
        pub fn delete(self: *Self) void {
            self.data.deinit();
        }
    };
}

const test_TilemapChunk = Chunk(u8, 16);
//const Vec2i = Vec2i;

test "TileMap.create" {
    var tm: Tilemap(u8, 16) = .init(testing.allocator);
    defer tm.delete();
}

test "TileMap.addChunk" {
    var tm: Tilemap(u8, 16) = .init(testing.allocator);
    defer tm.delete();

    const default_val: u8 = 3;
    const ch_data = [_][16]u8{
        [_]u8{default_val} ** 16
    } ** 16;

    try tm.addChunk(
        test_TilemapChunk.init(
            .vec2(0, 0),
            ch_data
        )
    );

    const tm_chunk_data: Chunk(u8, 16) = tm.data.get(.vec2(0,0)) orelse unreachable;
    for(tm_chunk_data.data) |chunkarr| {
        for(chunkarr) |tile| {
            try testing.expect(tile == default_val);
        }
    }

//    try testing.expect(false);
}

test "TileMap.modify" {
    var tm: Tilemap(u8, 16) = .init(testing.allocator);
    defer tm.delete();

    const ch_data = [_][16]u8{
        [_]u8{3} ** 16
    } ** 16;

    try tm.addChunk(
        .init(
            .vec2(0, 0),
            ch_data
        )
    );

    const mod_value: u8 = 7;

    try tm.modify(.vec2(5, 4), mod_value);

    const value = try tm.get(.vec2(5, 4));
    try testing.expect(value == mod_value);

    // const tm_chunk_data: Chunk(u8, 16) = tm.data.get(Vec2i.val(0,0)) orelse unreachable;
    // for(tm_chunk_data.data) |chunkarr| {
    //     for(chunkarr) |tile| {
    //         std.debug.print("{} ", .{tile});
    //     }
    //     std.debug.print("\n", .{});
    // }
}

test "TileMap.get" {
    var tm: Tilemap(u8, 16) = .init(testing.allocator);
    defer tm.delete();

    const ch_data = [_][16]u8{
        [_]u8{3} ** 16
    } ** 16;

    try tm.addChunk(.init(
        .vec2(0, 0),
        ch_data
    ));

    const tile_v: u8 = try tm.get(.vec2(7, 5));
    try testing.expect(tile_v == 3);
}

test "TileMap.getChunkPtr" {
    var tm: Tilemap(u8, 16) = .init(testing.allocator);
    defer tm.delete();

    try tm.addChunk(.initVal(
        .vec2(0, 0),
        0
    ));

    const chunk_ptr: *tm.TilemapChunk = try tm.getChunkPtr(.vec2(0, 0));
    try chunk_ptr.get(2, 2);
}
