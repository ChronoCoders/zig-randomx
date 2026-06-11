const std = @import("std");
const bindings = @import("c/bindings.zig");

pub const Flags = bindings.Flags;
pub const flag_default: Flags = 0;
pub const flag_full_mem: Flags = bindings.flag_full_mem;
pub const hash_size = bindings.hash_size;
pub const Hash = [hash_size]u8;

pub const Error = error{
    AllocationFailed,
    InitFailed,
    InvalidFlags,
};

pub fn recommendedFlags() Flags {
    return bindings.getFlags();
}

fn validateFlags(flags: Flags) Error!void {
    if (flags & ~bindings.flag_mask != 0) return Error.InvalidFlags;
}

pub const Cache = struct {
    allocator: std.mem.Allocator,
    handle: *bindings.Cache,

    pub fn init(allocator: std.mem.Allocator, flags: Flags, key: []const u8) Error!Cache {
        try validateFlags(flags);
        const handle = bindings.allocCache(flags) orelse return Error.AllocationFailed;
        bindings.initCache(handle, key);
        return .{ .allocator = allocator, .handle = handle };
    }

    pub fn deinit(self: Cache) void {
        bindings.releaseCache(self.handle);
    }
};

pub const Dataset = struct {
    allocator: std.mem.Allocator,
    handle: *bindings.Dataset,

    pub fn itemCount() usize {
        return bindings.datasetItemCount();
    }

    pub fn init(allocator: std.mem.Allocator, flags: Flags) Error!Dataset {
        try validateFlags(flags);
        const handle = bindings.allocDataset(flags) orelse return Error.AllocationFailed;
        return .{ .allocator = allocator, .handle = handle };
    }

    pub fn fill(self: Dataset, cache: Cache, start_item: usize, item_count: usize) void {
        bindings.initDataset(self.handle, cache.handle, start_item, item_count);
    }

    pub fn deinit(self: Dataset) void {
        bindings.releaseDataset(self.handle);
    }
};

pub const Vm = struct {
    allocator: std.mem.Allocator,
    handle: *bindings.Vm,

    pub fn init(allocator: std.mem.Allocator, flags: Flags, cache: Cache) Error!Vm {
        try validateFlags(flags);
        const handle = bindings.createVm(flags, cache.handle, null) orelse return Error.InitFailed;
        return .{ .allocator = allocator, .handle = handle };
    }

    pub fn initFast(allocator: std.mem.Allocator, flags: Flags, dataset: Dataset) Error!Vm {
        try validateFlags(flags);
        const handle = bindings.createVm(flags | flag_full_mem, null, dataset.handle) orelse return Error.InitFailed;
        return .{ .allocator = allocator, .handle = handle };
    }

    pub fn deinit(self: Vm) void {
        bindings.destroyVm(self.handle);
    }
};

pub fn hash(vm: Vm, input: []const u8) Hash {
    var out: Hash = undefined;
    bindings.calculateHash(vm.handle, input, &out);
    return out;
}

pub fn hashBatch(vm: Vm, inputs: []const []const u8, allocator: std.mem.Allocator) Error![]Hash {
    if (inputs.len == 0) return allocator.alloc(Hash, 0) catch Error.AllocationFailed;

    const out = allocator.alloc(Hash, inputs.len) catch return Error.AllocationFailed;
    errdefer allocator.free(out);

    bindings.calculateHashFirst(vm.handle, inputs[0]);
    var i: usize = 1;
    while (i < inputs.len) : (i += 1) {
        bindings.calculateHashNext(vm.handle, inputs[i], &out[i - 1]);
    }
    bindings.calculateHashLast(vm.handle, &out[inputs.len - 1]);
    return out;
}

const test_key = "RandomX example key\x00";
const test_input = "RandomX example input\x00";
const test_vector = [_]u8{
    0x8a, 0x48, 0xe5, 0xf9, 0xdb, 0x45, 0xab, 0x79,
    0xd9, 0x08, 0x05, 0x74, 0xc4, 0xd8, 0x19, 0x54,
    0xfe, 0x6a, 0xc6, 0x38, 0x42, 0x21, 0x4a, 0xff,
    0x73, 0xc2, 0x44, 0xb2, 0x63, 0x30, 0xb7, 0xc9,
};

test "recommendedFlags returns a subset of the known flag mask" {
    const flags = recommendedFlags();
    try std.testing.expectEqual(@as(Flags, 0), flags & ~bindings.flag_mask);
}

test "Cache.init rejects unknown flags" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(Error.InvalidFlags, Cache.init(allocator, ~bindings.flag_mask, test_key));
}

test "Cache.init and deinit succeed with default flags" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
}

test "Vm.init rejects unknown flags" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
    try std.testing.expectError(Error.InvalidFlags, Vm.init(allocator, ~bindings.flag_mask, cache));
}

test "Vm.init and deinit succeed with default flags" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
    var vm = try Vm.init(allocator, flag_default, cache);
    defer vm.deinit();
}

test "hash matches the known RandomX test vector" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
    var vm = try Vm.init(allocator, flag_default, cache);
    defer vm.deinit();

    const out = hash(vm, test_input);
    try std.testing.expectEqualSlices(u8, &test_vector, &out);
}

test "hashBatch matches per-input hashing" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
    var vm = try Vm.init(allocator, flag_default, cache);
    defer vm.deinit();

    const inputs = [_][]const u8{ test_input, "second input", "third input" };
    const batch = try hashBatch(vm, &inputs, allocator);
    defer allocator.free(batch);

    try std.testing.expectEqual(inputs.len, batch.len);
    try std.testing.expectEqualSlices(u8, &test_vector, &batch[0]);

    for (inputs, 0..) |in, idx| {
        const single = hash(vm, in);
        try std.testing.expectEqualSlices(u8, &single, &batch[idx]);
    }
}

test "hashBatch on empty input returns an empty slice" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();
    var vm = try Vm.init(allocator, flag_default, cache);
    defer vm.deinit();

    const empty = [_][]const u8{};
    const batch = try hashBatch(vm, &empty, allocator);
    defer allocator.free(batch);
    try std.testing.expectEqual(@as(usize, 0), batch.len);
}

test "Dataset.itemCount is non-zero" {
    try std.testing.expect(Dataset.itemCount() > 0);
}

test "fast-mode VM from a dataset produces consistent hashes" {
    const allocator = std.testing.allocator;
    var cache = try Cache.init(allocator, flag_default, test_key);
    defer cache.deinit();

    var dataset = try Dataset.init(allocator, flag_full_mem);
    defer dataset.deinit();
    dataset.fill(cache, 0, 1);

    var vm = try Vm.initFast(allocator, flag_default, dataset);
    defer vm.deinit();

    const first = hash(vm, test_input);
    const second = hash(vm, test_input);
    try std.testing.expectEqualSlices(u8, &first, &second);
}
