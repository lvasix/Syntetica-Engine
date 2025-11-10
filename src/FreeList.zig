//! FreeList implementation for Syntetica Engine.

const std = @import("std");

pub const FreeListSlice = struct {
    start: usize,
    end: usize,
    size: usize,
};

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
            list_is_empty,
        };

        /// Data type used for iterating over the SimpleLinkedFreeList.
        const Iterator = struct {
            /// free list
            fl: *Self,

            current_data: DataType = undefined,
            current_id: usize = 0,
            next_id: usize = 0,
            count: usize = 0,

            pub fn next(self: *Iterator) ?DataType {
                self.current_id = self.next_id;

                self.current_data = self.fl.data[self.current_id];

                self.next_id = self.fl._data_info[self.current_id].next;

                const ret = 
                    if(self.count == self.fl._occupied) 
                        null 
                    else 
                        @as(?DataType, self.current_data);

                self.count += 1;

                return ret;
            }

            pub fn reset(self: *Iterator) FreeListError!void {
                self.count = 0;
                self.next_id = self.fl._start orelse 
                    return FreeListError.start_does_not_exist;
                self.current_id = 0;
            }
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
            // if we can fit more elements (num of occupied is not more than data lenght), then
            // just return and don't resize anything
            if(!(self._occupied >= self.data.len)) return;

            self.data = 
                try self.allocator.realloc(self.data, self.data.len + alloc_size);

            self._data_info = 
                try self.allocator.realloc(self._data_info, self._data_info.len + alloc_size);

            self._free_space = 
                try self.allocator.realloc(self._free_space, self._free_space.len + alloc_size);

            // insert the IDs into the available IDs list
            for(self._free_space, 1..) |*data, i| {
                data.* = self._free_space.len - i;
            }
        }

        /// Internal function that does the same this as checkAndResize, but for multiple
        /// elements. Instead of checking if a single element will fit, it checks if 
        /// N-amount of elements will fit (and resizes)
        fn checkAndResizeN(self: *Self, n: usize) !void {
            // check if the new elements would fit
            if(!(self._occupied >= self.data.len + n)) return;

            // normally, we'd do only alloc_size for one element, 
            // but we are allocating for N elements, so we multiply 
            // the alloc_size.
            const new_size = alloc_size * n;

            self.data = 
                try self.allocator.realloc(self.data, self.data.len + new_size);

            self._data_info = 
                try self.allocator.realloc(self._data_info, self._data_info.len + new_size);

            self._free_space = 
                try self.allocator.realloc(self._free_space, self._free_space.len + new_size);

            // insert the IDs into the available IDs list
            for(self._free_space, 1..) |*data, i| {
                data.* = self._free_space.len - i;
            }
        }

        fn link(self: *Self, id: usize) void {
            if(self._start == null) {
                self._start = id;
                self._data_info[id].prev = id;
                self._data_info[id].next = id;
            } else {
                // set our last to root's last
                self._data_info[id].prev = self._data_info[ self._start.? ].prev;

                // set ourselves as root's last
                self._data_info[self._start.?].prev = id;

                // set our next to root
                self._data_info[id].next = self._start.?; 

                // set ourselves as our new previous' next
                self._data_info[self._data_info[id].prev].next = id; 
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
                data.* = alloc_size - i - 1;
            }

            obj._initialized = true;
            return obj;
        }

        /// Inserts new value into the SimpleLinkedFreeList
        pub fn insert(self: *Self, data: DataType) !usize {
            if(self._initialized == false) return FreeListError.not_initialized;
            try self.checkAndResize();

            const id = 
                self._free_space[self.data.len - self._occupied - 1] orelse unreachable;
            self._free_space[self.data.len - self._occupied - 1] = null;
            self._occupied += 1;

            self.link(id);

            // assign the data to the reserved ID
            self.data[id] = data;

            return id;
        }

        /// inserts a slice of FreeList's type as individual elements, linked together,
        /// performs size check once, thus a bit efficient than just using insert for 
        /// every element, especially when adding a lot of elements
        ///
        /// @return FreeListSlice containing the first and the last element
        pub fn insertSlice(self: *Self, slice: []const DataType) !FreeListSlice {
            if(self._initialized == false) return FreeListError.not_initialized;
            try self.checkAndResizeN(slice.len - 1);

            const start = 
                self._free_space[self.data.len - self._occupied - 1] orelse unreachable;
            self._free_space[self.data.len - self._occupied - 1] = null;
            self._occupied += 1;

            self.data[start] = slice[0];

            self.link(start);

            var end: usize = 0;
            for(slice[1..]) |data| {
                const id =
                    self._free_space[self.data.len - self._occupied - 1] orelse unreachable;
                self._free_space[self.data.len - self._occupied - 1] = null;
                self._occupied += 1;

                self.link(id);

                self.data[id] = data;
                end = id;
            }

            return .{
                .start = start,
                .end = end,
                .size = slice.len,
            };
        }

        pub fn deleteSlice(self: *Self, slice: FreeListSlice) !void {
            for(try self.listIDs()) |id| {
                _ = id;
            }
            _ = slice;
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

        pub fn createIterator(self: *Self) FreeListError!Iterator {
            if(self._occupied == 0) return FreeListError.list_is_empty;

            return .{
                .fl = self,
                .next_id = self._start orelse return FreeListError.start_does_not_exist,
            };
        }

        pub fn find(self: *Self, cmp_data: DataType) !usize {
            for(try self.listIDs()) |id| {
                const data = self.get(id);
                if(std.meta.eql(data, cmp_data)) return id;
            }
            return FreeListError.element_not_found;
        }

        /// wrapper for legacy support, if possible, replace all instances
        /// of this function with deinit()
        pub fn release(self: *Self) void {
            self.deinit();
        }

        pub fn deinit(self: *Self) void {
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

const FL = SimpleLinkedFreeList(u8, 20);

test "SimpleLinkedFreeList.createIterator" {
    var fl = try FL.init(testing.allocator);
    defer fl.release();

    // free list should return an error for no elements
    try testing.expectError(error.list_is_empty, fl.createIterator());

    _ = try fl.insert(5);

    var it = try fl.createIterator();
    _ = &it;

    try testing.expectEqual(it.next_id, fl._start);
}

test "SimpleLinkedFreeList.Iterator.next" {
    var fl = try FL.init(testing.allocator);
    defer fl.release();

    _ = try fl.insert(5);
    _ = try fl.insert(4);
    _ = try fl.insert(2);
    _ = try fl.insert(0xFF);

    var it = try fl.createIterator();

    try testing.expectEqual(@as(?u8, 5), it.next());
    try testing.expectEqual(@as(?u8, 4), it.next());
    try testing.expectEqual(@as(?u8, 2), it.next());
    try testing.expectEqual(@as(?u8, 0xFF), it.next());
    try testing.expectEqual(@as(?u8, null), it.next());
}

test "SimpleLinkedFreeList.Iterator.reset" {
    var fl = try FL.init(testing.allocator);
    defer fl.release();

    _ = try fl.insert(5);
    _ = try fl.insert(4);

    var it = try fl.createIterator();

    _ = it.next();
    _ = it.next();
    _ = it.next();

    try it.reset();

    try testing.expectEqual(0, it.count);
    try testing.expectEqual(it.fl._start, it.next_id);
    try testing.expectEqual(0, it.current_id);
}

test "SimpleLinkedFreeList.insertSlice" { 
    var fl = try FL.init(testing.allocator);
    defer fl.release();

    _ = try fl.insert(5);
    const s = try fl.insertSlice(&.{4, 5, 2, 6});

    try testing.expectEqual(1, s.start);
    try testing.expectEqual(4, s.end);
    try testing.expectEqual(4, s.size);
}
