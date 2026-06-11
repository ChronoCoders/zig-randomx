const std = @import("std");

const c = @cImport({
    @cInclude("randomx.h");
});

pub const hash_size: usize = @intCast(c.RANDOMX_HASH_SIZE);

pub const Flags = u32;

pub const flag_mask: Flags =
    @as(Flags, @intCast(c.RANDOMX_FLAG_LARGE_PAGES)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_HARD_AES)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_FULL_MEM)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_JIT)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_SECURE)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_ARGON2_SSSE3)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_ARGON2_AVX2)) |
    @as(Flags, @intCast(c.RANDOMX_FLAG_V2));

pub const Cache = c.randomx_cache;
pub const Dataset = c.randomx_dataset;
pub const Vm = c.randomx_vm;

fn toC(flags: Flags) c.randomx_flags {
    return @intCast(flags);
}

pub fn getFlags() Flags {
    return @intCast(c.randomx_get_flags());
}

pub fn allocCache(flags: Flags) ?*Cache {
    return c.randomx_alloc_cache(toC(flags));
}

pub fn initCache(cache: *Cache, key: []const u8) void {
    const key_ptr: ?*const anyopaque = @ptrCast(key.ptr);
    c.randomx_init_cache(cache, key_ptr, key.len);
}

pub fn releaseCache(cache: *Cache) void {
    c.randomx_release_cache(cache);
}

pub fn allocDataset(flags: Flags) ?*Dataset {
    return c.randomx_alloc_dataset(toC(flags));
}

pub fn releaseDataset(dataset: *Dataset) void {
    c.randomx_release_dataset(dataset);
}

pub fn createVm(flags: Flags, cache: *Cache, dataset: ?*Dataset) ?*Vm {
    return c.randomx_create_vm(toC(flags), cache, dataset);
}

pub fn destroyVm(vm: *Vm) void {
    c.randomx_destroy_vm(vm);
}

pub fn calculateHash(vm: *Vm, input: []const u8, output: *[hash_size]u8) void {
    const in_ptr: ?*const anyopaque = @ptrCast(input.ptr);
    const out_ptr: ?*anyopaque = @ptrCast(output);
    c.randomx_calculate_hash(vm, in_ptr, input.len, out_ptr);
}

pub fn calculateHashFirst(vm: *Vm, input: []const u8) void {
    const in_ptr: ?*const anyopaque = @ptrCast(input.ptr);
    c.randomx_calculate_hash_first(vm, in_ptr, input.len);
}

pub fn calculateHashNext(vm: *Vm, next_input: []const u8, output: *[hash_size]u8) void {
    const in_ptr: ?*const anyopaque = @ptrCast(next_input.ptr);
    const out_ptr: ?*anyopaque = @ptrCast(output);
    c.randomx_calculate_hash_next(vm, in_ptr, next_input.len, out_ptr);
}

pub fn calculateHashLast(vm: *Vm, output: *[hash_size]u8) void {
    const out_ptr: ?*anyopaque = @ptrCast(output);
    c.randomx_calculate_hash_last(vm, out_ptr);
}

test "flag mask contains the default flag set" {
    try std.testing.expectEqual(@as(Flags, 0), @as(Flags, @intCast(c.RANDOMX_FLAG_DEFAULT)));
    try std.testing.expect(flag_mask & @as(Flags, @intCast(c.RANDOMX_FLAG_JIT)) != 0);
}

test "hash size matches the C constant" {
    try std.testing.expectEqual(@as(usize, 32), hash_size);
}
