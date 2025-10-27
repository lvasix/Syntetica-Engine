const std = @import("std");
const api = @import("syntetica").Entity.api;

const Player = struct {
    const DataType = struct {
        foo: bool,
        equiped_items: [4]u32 = [1]u32{0} ** 4, // placeholder
    };

    /// mandatory data field declaration
    pub var data: api.Data(DataType) = .{};

    pub fn init(self: api.args) !void {
        self.entity_data_id = try data.reqData(); 
        std.debug.print("INIT: .Player#{}\n", .{self.entityID});
    }

    pub fn tick(self: api.args) void {
        data.get(self.entity_data_id).foo = true;
    }

    pub fn kill(self: api.args) void {
        defer data.delData(self.entity_data_id);
        std.debug.print("KILL: .Player#{}\n", .{self.entityID});
        std.debug.print("  foo: {}\n", .{data.get(self.entity_data_id).foo});
        std.debug.print("  EDAID: {}\n", .{self.entity_data_id});
    }
};

const Enemy = struct {
    const DataType = struct {
        equiped_items: [4]u32 = [1]u32{0} ** 4, // placeholder
    };

    /// mandatory data field declaration
    pub var data: api.Data(DataType) = .{};

    pub fn init(self: api.args) !void {
        self.entity_data_id = try data.reqData();
        std.debug.print("INIT: .Enemy#{}\n", .{self.entityID});
    }

    pub fn tick(self: api.args) void {
        _ = self;
    }

    pub fn kill(self: api.args) void {
        defer data.delData(self.entity_data_id);
        std.debug.print("KILL: .Enemy#{}\n", .{self.entityID});
    }
};

pub const entity_list = [_]type{
    Player,
    Enemy,
};
