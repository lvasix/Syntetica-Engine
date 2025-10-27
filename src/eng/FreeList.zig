const std = @import("std");

pub fn SimpleLinkedFreeList(DataType: type, alloc_size: usize) type {
    return struct {
        const Self = @This();

        /// metadata struct for data
        const DataMeta = struct {
            prev: usize,
            next: usize,

        };

        const FreeListError = error {
            element_not_found,
            start_does_not_exist,
            not_initialized,
        };

        _initialized: bool = false,

        /// elements array
        data: []DataType = undefined,

        /// metadata for elements
        _data_info: []DataMeta = undefined,

        /// array of available elements
        _free_space: []?usize = undefined,
        
        /// First element of the linked list
        _start: ?usize = null, 
        _occupied: usize = 0,

        /// used for easier iterating over the freelist
        _compact_list: []usize = &[0]usize{},

        /// allocator
        allocator: std.mem.Allocator = undefined,

        /// Internal function used for checking the size of the internal data, _data_info and _free_space arrays.
        fn checkAndResize(self: *Self) !void {
            if(!(self._occupied >= self.data.len)) return;

            self.data = try self.allocator.realloc(self.data, self.data.len + alloc_size);
            self._data_info = try self.allocator.realloc(self._data_info, self.data.len + alloc_size);
            self._free_space = try self.allocator.realloc(self._free_space, self.data.len + alloc_size);

            for(self._free_space, self._occupied..) |*data, i| {
                data.* = i;
            }
        }

        /// Initialize the SimpleLinkedFreeList type with an allocator of choice
        ///
        /// @param allocator std.mem.Allocator of choice
        ///
        /// @return SimpleLinkedFreeList
        pub fn init(allocator: std.mem.Allocator) !Self {
            var obj: Self = .{};

            obj.allocator = allocator;

            obj.data = try obj.allocator.alloc(DataType, alloc_size);
            obj._data_info = try obj.allocator.alloc(DataMeta, alloc_size);
            obj._free_space = try obj.allocator.alloc(?usize, alloc_size);
            
            // I'm not too sure about allocating 0 bytes, but that memory won't be used anyway,
            // and it seems to grow fine. Maybe find a way to make this work safer in the future.
            obj._compact_list = try obj.allocator.alloc(usize, 0); 

            for(obj._free_space, 0..) |*data, i| {
                data.* = i;
            }

            obj._initialized = true;
            return obj;
        }

        /// Inserts new value into the SimpleLinkedFreeList
        pub fn insert(self: *Self, data: DataType) !usize {
            if(self._initialized == false) return FreeListError.not_initialized;
            try self.checkAndResize();

            const id = self._free_space[self.data.len - self._occupied - 1] orelse unreachable;
            self._free_space[self.data.len - self._occupied - 1] = null;
            self._occupied += 1;

            // linking
            if(self._start == null) {
                self._start = id;
                self._data_info[id].prev = id;
                self._data_info[id].next = id;
            } else {
                self._data_info[id].prev = self._data_info[ self._start.? ].prev; // set our last to root's last
                self._data_info[self._start.?].prev = id; // set ourselves as root's last
                self._data_info[id].next = self._start.?; // set our next to root
                self._data_info[self._data_info[id].prev].next = id; // set ourselves as our new previous' next
            }

            // assign the data to the reserved ID
            self.data[id] = data;

            return id;
        }

        /// deletes an ID from SimpleLinkedFreeList, use this when you are done with 
        /// using a place in the SimpleLinkedFreeList.
        pub fn deleteID(self: *Self, id: usize) void {
            // add the id back to stack
            self._free_space[self.data.len - self._occupied] = id;

            // handle edge case when deleting a root node which is also last
            if(self._start == id and self._occupied <= 1) {
                self._start = null;
            } else {
                // remove the element from linked list
                self._data_info[self._data_info[id].prev].next = self._data_info[id].next; // our previous' next = our next
                self._data_info[self._data_info[id].next].prev = self._data_info[id].prev; // our next's previous = our previous
                
                if(self._start == id) { // if the node we are trying to delete is root
                    self._start = self._data_info[id].next; // our next node becomes the root
                }
            }

            // decrement the element count
            self._occupied -= 1;
        }

        /// returns the data stored at a specified ID
        pub fn get(self: *Self, id: usize) DataType {
            return self.data[id];
        }

        /// returns the pointer to the data stored at a specified ID
        pub fn getPtr(self: *Self, id: usize) *DataType {
            return &self.data[id];
        }

        /// return all elements of the SimpleLinkedFreeList as an iterable (and unsorted) array.
        /// Can return error if allocation for the iterable array fails.
        pub fn listIDs(self: *Self) ![]usize {
            if(self._compact_list.len == self._occupied) return self._compact_list; 

            self._compact_list = try self.allocator.realloc(self._compact_list, self._occupied);

            var current_id: usize = self._start orelse return FreeListError.start_does_not_exist;
            for(self._compact_list) |*index| {
                index.* = current_id;
                current_id = self._data_info[current_id].next;
            }

            return self._compact_list;
        }

        pub fn find(self: *Self, cmp_data: DataType) !usize {
            for(try self.listIDs()) |id| {
                const data = self.get(id);
                if(std.meta.eql(data, cmp_data)) return id;
            }
            return FreeListError.element_not_found;
        }

        pub fn release(self: *Self) void {
            if(self._initialized == false) return;

            self.allocator.free(self.data);
            self.allocator.free(self._data_info);
            self.allocator.free(self._free_space);
            self.allocator.free(self._compact_list);
            self._initialized = false;
        }

        /// sets the whole struct to 0. Does not initialize the FreeList.
        pub fn zero() Self {
            const obj: Self = std.mem.zeroInit(Self, .{});

            return obj;
        }
    };
}

const freelist = @This();
const testing = std.testing;
// test "freelist_general" {
//     var fl: freelist.SimpleLinkedFreeList(u32, 5) = try .init(testing.allocator);
//
//     for(0..10) |i| {
//         const id = try fl.insert(@intCast(i));
//         std.debug.print("id: {} = {}\n", .{id, i});
//     }
//
//     std.debug.print("STRUCT: {}\n", .{fl});
//
//     std.debug.print("IDs: ", .{});
//     for(try fl.listIDs()) |data_id| {
//         std.debug.print("{}<-{}:{}->{} ", .{fl._data_info[data_id].prev, fl.data[data_id], data_id, fl._data_info[data_id].next});
//     }
//     std.debug.print("\n", .{});
//
//     std.debug.print("DATA: ", .{});
//     for(try fl.listIDs()) |data_id| {
//         const data = fl.get(data_id);
//         std.debug.print("{}, ", .{data});
//     }
//     std.debug.print("\n", .{});
//
//     std.debug.print("{!}", .{fl.find(5)});
//
//     fl.release();
// }
