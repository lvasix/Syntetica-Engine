//! @file Entity.zig 
//! @brief Entity struct
//! 
//! EXAMPLE ON DEFINING ENTITIES:
//! ```Zig 
//! const Entity = @import("Entity.zig");
//! const FooEntity = struct {
//!     const DataType = struct {
//!         // data your entity will carry.
//!     };
//!     
//!     pub var data: Entity.DataContainer(DataType) = .{};
//!
//!     pub fn init(self: *Entity.fnArgs) !void {
//!         self.entity_data_id = try data.reqData(); // request data for every new entity
//!     }
//!
//!     pub fn tick(self: *Entity.fnArgs) void {
//!         // put main logic here
//!     }
//!
//!     pub fn kill(self: *Entity.fnArgs) void {
//!         defer data.delData(self.entity_data_id); // when the entity is killed, remove its data.
//!     }
//! };
//!
//! // ... (somewhere where you want to init your entities)
//! {
//!     var manager: Entity.CreateManager(&.{FooEntity}) = .init(allocator_of_your_choice);
//!     defer manager.release();
//!     const id = manager.spawn(.FooEntity); // reference the entities as enum fields.
//!     manager.tick(); // tick all entities.
//!     manager.kill(id); // to kill an entity, just reference it's ID.
//! }
//! ```
//! - - -
//! For more info on how to use this, check out the code or examples.

/// standard library
const std = @import("std");

/// custom free list implementation
const FreeList = @import("FreeList.zig");

const Entity = @This();

/// Arguments which are passed into the entity functions
pub const fnArgs = struct {
    /// entity ID in the world
    entityID: usize = 0,

    /// entity data ID, used for accessing the data array
    entity_data_id: usize = 0,
};

/// Manager's internal entity registry type
pub const entRegistry = struct {
    fn_init: *const fn(*fnArgs) anyerror!void,
    fn_tick: *const fn(*fnArgs) void,
    fn_kill: *const fn(*fnArgs) void,
};

/// internal function for getting the name of an function as a null-terminated
/// string, without the path resoultion.
///
/// @param T type to get the name of 
/// @return sentiel terminated string containing the name of the type as a string
///
/// Example: 
/// ```Zig 
/// const Foo = struct {};
/// const name = getEntityName(Foo); 
/// // name = "Foo" here
/// ```
fn getEntityName(comptime T: type) [:0]const u8 {
    var iter = std.mem.splitBackwardsScalar(u8, @typeName(T), '.');
    return @as([:0]const u8, iter.first() ++ "");
}

/// Create a manager type for entities. It generates an enum based on the 
/// names of supplied types.
/// 
/// @param entities an array of types containing your entities.
/// @return returns the actual Manager type
///
/// Example:
/// ```Zig
/// var manager: Manager(&.{Type1, Type2, Type3}) = ...;
/// ```
pub fn Manager(comptime entities: []const type) type {
    var entity_fields: [entities.len + 1]std.builtin.Type.EnumField = undefined;

    // create an array of strings for the enum
    inline for (entities, 0..) |entity, i| {
        if(!@hasDecl(entity, "data")) @compileError("Entity type must have a data declaration");

        // assign the enum field
        entity_fields[i] = std.builtin.Type.EnumField{
            .name = getEntityName(entity),
            .value = i,
        };
    }

    // add last element to be .undef for handling edge cases and errors
    entity_fields[entities.len] = .{.name = "undef", .value = entities.len};

    // create the enum 
    const ent_enum_type: type = @Type(.{.@"enum" = .{
        .decls = &.{},
        .tag_type = u32,
        .fields = &entity_fields,
        .is_exhaustive = false,
    }});

    return struct {
        /// Type alias for the Manager structure
        const ThisManager = @This();

        /// Entity data container for the actual world entities. These are 
        /// the actual instances of entities in the world, referenced by
        /// the entity world ID.
        pub const WorldEntity = struct {
            /// World entity process ID
            eid: usize = 0, 

            /// entity data array ID
            edaID: usize = 0,

            /// World entity type
            entity_type: ent_enum_type = .undef,

            /// used for keeping track of alive entities
            entity_is_alive: bool = false,
        };

        /// Entity enum type
        pub const EntEnum: type = ent_enum_type;

        /// array containing all of the functions, indeces of this table correspond to 
        /// the numerical values of enum fields in the "ent_enum_type" enum.
        entity_function_table: [entities.len]entRegistry = undefined,

        /// current simulation tick
        sim_tick: usize = 0,

        /// entity data of type WorldEntity.
        world_entities: FreeList.SimpleLinkedFreeList(WorldEntity, 200) = .zero(),

        /// Initialize the manager.
        /// 
        /// @param allocator allocator that the manager will use for memory.
        /// @return manager, can return error if FreeList init fails.
        ///
        /// Example:
        /// ```Zig  
        /// var manager: CreateManager(&.{Entity1, Entity2, Entity3}) = .init(ALLOCATOR);
        /// ```
        pub fn init(allocator: std.mem.Allocator) !ThisManager {
            var man = ThisManager{
                .world_entities = try .init(allocator),
            };

            // do the assigning of all function pointers, also initialize the 
            // private data of entities.
            inline for(entities, 0..) |entity, i| {
                man.entity_function_table[i].fn_init = entity.init;
                man.entity_function_table[i].fn_tick = entity.tick;
                man.entity_function_table[i].fn_kill = entity.kill;
                entity.data.data = try @TypeOf(entity.data.data).init(allocator);
                entity.data._initialized = true;
            }

            return man;
        }

        /// Spawn an entity. 
        ///
        /// @param self reference to the Manager
        /// @param entity which entity to spawn 
        /// @return id of the spawned entity or error if spawning fails.
        ///
        /// Example:
        /// ```Zig 
        /// // Assuming .Foo is defined, check out Manager(...) and .init(...)
        /// // for more details
        /// var manager: Manager(...) = ...;
        /// const entity_id = manager.spawn(.Foo);
        /// ```
        pub fn spawn(self: *ThisManager, entity: ent_enum_type) !usize {
            const id = try self.world_entities.insert(.{.entity_type = entity}); // get the entity world data
            self.world_entities.getPtr(id).eid = id; // update the world data of the entity to hold its EID

            // prepare data needed for the Entity's init() function call.
            const table_index = @as(usize, @intFromEnum(entity));
            var arguments = fnArgs{
                .entityID = id,
                .entity_data_id = 0, // since init() will most likely create a new data instance, this can be 0
                                     // TODO: prob should make this an optional
            };

            // init() can fail so we handle that
            try self.entity_function_table[table_index].fn_init(&arguments);

            // apply changes that may have occured in the init function.
            self.world_entities.getPtr(id).edaID = arguments.entity_data_id;

            return id;
        }

        /// Get a pointer to the world entity's data.
        ///
        /// @param self reference to the Manager 
        /// @param entity_id which world entity to get reference 
        /// @return pointer to the world entity's data 
        ///
        /// Example:
        /// ```Zig
        /// var manager = ...;
        /// const ent_ptr = manager.getEntityPtr(2);
        /// ```
        pub fn getEntityPtr(self: *ThisManager, entity_id: usize) *WorldEntity {
            return self.world_entities.getPtr(entity_id);
        }

        /// Kills a specified entity ID.
        ///
        /// @param self reference to the Manager 
        /// @param entity_id entity's ID that you want to kill 
        /// @return void 
        ///
        /// Example:
        /// ```Zig 
        /// const manager: Manager(...) = .init(...);
        /// const id = manager.spawn(...);
        /// manager.kill(id);
        /// ```
        pub fn kill(self: *ThisManager, entity_id: usize) void {
            // TODO: implement check for the existance of the entity
            const entity = self.world_entities.get(entity_id);

            var arguments = fnArgs{
                .entityID = entity.eid,
                .entity_data_id = entity.edaID
            };

            // run the entity's kill function
            self.entity_function_table[@intFromEnum(entity.entity_type)].fn_kill(&arguments);

            self.world_entities.deleteID(entity_id);
        }

        /// Advances the tick of the simulation 
        ///
        /// @param self reference to the Manager 
        /// @return error if iterating over IDs fails.
        ///
        /// Example:
        /// ```Zig 
        /// const manager: Manager(...) = .init(...);
        /// try manager.tick();
        /// ```
        pub fn tick(self: *ThisManager) !void {
            if(self.world_entities._start == null) return;

            for(try self.world_entities.listIDs()) |entity_id| {
                const index = @as(usize, @intFromEnum(self.world_entities.getPtr(entity_id).entity_type));
                const entity_ptr = self.world_entities.getPtr(entity_id);

                var arguments = fnArgs{
                    .entityID = entity_id,
                    .entity_data_id = entity_ptr.edaID,
                };

                const entity_function = self.entity_function_table[index].fn_tick;
                entity_function(&arguments);

                // Apply changes that may have occured during the tick function
                entity_ptr.edaID = arguments.entity_data_id;
            }
        }

        /// Relases all resources used by the Manager.
        ///
        /// @param self reference to the Manager 
        /// @return void 
        ///
        /// Example:
        /// ```Zig 
        /// var manager: Manager(...) = .init(...);
        /// defer manager.release();
        /// /// ... (do something with the manager)
        /// ```
        pub fn release(self: *ThisManager) void {
            // delete any remaining entities

            if(self.world_entities._start != null) {
                for(self.world_entities.listIDs() catch @panic("Failed releasing manager")) |entityID| {
                    self.kill(entityID);
                }
            }

            // iterating over an array of types, thus must be an inline for loop
            inline for(entities) |entity| { // release all of the entity internal data
                entity.data.data.release();
                entity.data._initialized = false;
            }

            self.world_entities.release();
        }
    };
}

/// Data container for entity definitions.
///
/// @param DataType Type of data the container will hold.
/// @return The container as a struct
///
/// Example:
/// ```Zig
/// //... (inside the entity struct)
/// 
/// pub var data: DataContainer(TYPE) = .{};
///
/// //...
/// ```
pub fn DataContainer(DataType: type) type {
    return struct {
        const Self = @This();

        /// check for if the DataContainer is initialized
        _initialized: bool = false,

        /// data of the entities
        data: FreeList.SimpleLinkedFreeList(DataType, 20) = undefined,

        /// requests data for the entity. Must be ran in the 
        /// init() function of the entity if the desire is to 
        /// use the data functionality.
        ///
        /// @param self reference to the DataContainer
        /// @return index of the entity's data or error if getting it fails.
        ///
        /// Example:
        /// ```Zig 
        /// const data: DataContainer(...) = .{};
        ///
        /// pub fn init(self: *fnArgs) !void {
        ///     self.entity_data_id = try data.regData();
        /// }
        /// ```
        pub fn reqData(self: *Self) !usize {
            return self.data.insert(undefined);
        }

        /// deletes data by ID. Must be ran in the kill() function of the entity if 
        /// the desire is to fully dispose of data. If this step is not done, UB may 
        /// happen !!!
        ///
        /// @param self reference to the DataContainer 
        /// @param id entity's data ID 
        /// @return void
        ///
        /// Example:
        /// ```Zig
        /// const data = DataContainer(...) = .{};
        ///
        /// pub fn kill(self: *fnArgs) void {
        ///     data.delData(self.entity_data_id);
        /// }
        /// ```
        pub fn delData(self: *Self, id: usize) void {
            self.data.deleteID(id);
        }

        /// get the data for a specified entity data ID.
        ///
        /// @param self reference to the DataContainer
        /// @param id entity's data ID 
        /// @return pointer to the entity data 
        ///
        /// Example:
        /// ```Zig 
        /// const data = DataContainer(...) = .{};
        ///
        /// pub fn tick(self: *fnArgs) void {
        ///     const data_ptr = data.get(self.entity_data_id);
        ///     // ... do something with data_ptr.
        /// }
        /// ```
        pub fn get(self: *Self, id: usize) *DataType { 
            return self.data.getPtr(id);
        }
    };
}

// ////////////////////////////////////////////////////// 
// / UNIT TESTS ///////////////////////////////////////// 
// //////////////////////////////////////////////////////

const testing = std.testing;
test "fnArgs" {
    const foo: fnArgs = .{};
    try testing.expect(@TypeOf(foo.entityID) == usize);
    try testing.expect(@TypeOf(foo.entity_data_id) == usize);
}

test "entRegistry" {
    const foo: entRegistry = undefined;
    try testing.expect(@TypeOf(foo.fn_tick) == *const fn(*fnArgs) void);
    try testing.expect(@TypeOf(foo.fn_kill) == *const fn(*fnArgs) void);
    try testing.expect(@TypeOf(foo.fn_init) == *const fn(*fnArgs) anyerror!void);
}

test "getEntityName" {
    const Foo = struct {};
    const name = comptime getEntityName(Foo);
    try testing.expect(@TypeOf(name) == [:0]const u8);
    try testing.expect(std.mem.eql(u8, name, "Foo"));
}

test "Manager" {
    const FooEntity = struct {

        /// mandatory data field declaration
        pub var data: Entity.DataContainer(u8) = .{};

        pub fn init(self: *fnArgs) !void {
            _ = self;
        }

        pub fn tick(self: *fnArgs) void {
            _ = self;
        }

        pub fn kill(self: *fnArgs) void {
            _ = self;
        }
    };

    const FooEntity1 = struct {
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self;}
    };

    const man = Manager(&.{FooEntity, FooEntity1});
    try testing.expect(@hasField(man.EntEnum, "FooEntity"));
    try testing.expect(@hasField(man.EntEnum, "FooEntity1"));
}

test "Manager.init" {
    const FooEntity = struct {
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);
    defer man.release();

    try testing.expect(man.world_entities._initialized);

    try testing.expect(man.entity_function_table[0].fn_init == FooEntity.init);
    try testing.expect(man.entity_function_table[0].fn_tick == FooEntity.tick);
    try testing.expect(man.entity_function_table[0].fn_kill == FooEntity.kill);
    try testing.expect(FooEntity.data.data._initialized);
    try testing.expect(FooEntity.data._initialized);

    try testing.expect(man.sim_tick == 0);
}

test "Manager.spawn" {
    const FooEntity = struct {
        pub var init_ran: bool = false;
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {
            self.entityID = 999; // if this suceeds, the test should fail since we should not be allowed 
                                 // to change this field. it's readonly
            self.entity_data_id = 2; // this should suceed
            init_ran = true;
        }
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);
    defer man.release();

    const id = try man.spawn(.FooEntity);

    try testing.expect(FooEntity.init_ran);
    try testing.expect(man.world_entities._occupied == 1);
    try testing.expect(man.world_entities.data[id].eid == id);
    try testing.expect(man.world_entities.data[id].edaID == 2);
    try testing.expect(man.world_entities.data[id].entity_type == .FooEntity);
}

test "Manager.getEntityPtr" {
    const FooEntity = struct {
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);
    defer man.release();

    const id = try man.spawn(.FooEntity);

    const ptr = man.getEntityPtr(id);

    try testing.expect(ptr.eid == id);
}

test "Manager.kill" {
    const FooEntity = struct {
        pub var was_kill_ran = false;
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self; was_kill_ran = true;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);
    defer man.release();
    const id = try man.spawn(.FooEntity);

    man.kill(id);
    try testing.expect(FooEntity.was_kill_ran);
    // when the actual system for recording a removed item from the free list is 
    // implemented, check that 
}

test "Manager.tick" {
    const FooEntity = struct {
        pub var was_tick_ran = false;
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {
            self.entityID = 999;
            self.entity_data_id = 2;

            was_tick_ran = true;
        }
        pub fn kill(self: *fnArgs) void {_ = self;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);
    defer man.release();
    const id = try man.spawn(.FooEntity);

    try man.tick();

    try testing.expect(man.world_entities.data[id].eid == id);
    try testing.expect(man.world_entities.data[id].edaID == 2);
    try testing.expect(FooEntity.was_tick_ran);
}

test "Manager.release" {
    const FooEntity = struct {
        pub var was_kill_ran = false;
        pub var data: Entity.DataContainer(u8) = .{};
        pub fn init(self: *fnArgs) !void {_ = self;}
        pub fn tick(self: *fnArgs) void {_ = self;}
        pub fn kill(self: *fnArgs) void {_ = self; was_kill_ran = true;}
    };

    var man: Manager(&.{FooEntity}) = try .init(testing.allocator);

    _ = try man.spawn(.FooEntity);

    man.release();

    try testing.expect(FooEntity.was_kill_ran);
    try testing.expect(!FooEntity.data._initialized);
    try testing.expect(!man.world_entities._initialized);
}

test "DataContainer.reqData" {
    var cont: DataContainer(u8) = .{};
    cont.data = try @TypeOf(cont.data).init(testing.allocator);
    defer cont.data.release();

    const id = try cont.reqData();
    try testing.expect(@TypeOf(id) == usize);
}

test "DataContainer.delData" {
    var cont: DataContainer(u8) = .{};
    cont.data = try @TypeOf(cont.data).init(testing.allocator);
    defer cont.data.release();

    const id = try cont.reqData();

    const occ = cont.data._occupied;
    cont.delData(id);
    try testing.expect(cont.data._occupied != occ);
}

test "DataContainer.get" {
    var cont: DataContainer(u8) = .{};
    cont.data = try @TypeOf(cont.data).init(testing.allocator);
    defer cont.data.release();

    const id = try cont.reqData();
    const ptr = cont.data.getPtr(id);
    ptr.* = 5;

    const val = cont.get(id).*;

    try testing.expectEqual(5, val);
}
