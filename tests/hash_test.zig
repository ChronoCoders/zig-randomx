const std = @import("std");
const randomx = @import("randomx");

const key = "RandomX example key\x00";
const input = "RandomX example input\x00";

const expected = [_]u8{
    0x8a, 0x48, 0xe5, 0xf9, 0xdb, 0x45, 0xab, 0x79,
    0xd9, 0x08, 0x05, 0x74, 0xc4, 0xd8, 0x19, 0x54,
    0xfe, 0x6a, 0xc6, 0x38, 0x42, 0x21, 0x4a, 0xff,
    0x73, 0xc2, 0x44, 0xb2, 0x63, 0x30, 0xb7, 0xc9,
};

test "known RandomX test vector from api-example1.c" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm.deinit();

    const out = randomx.hash(vm, input);
    try std.testing.expectEqualSlices(u8, &expected, &out);
}

test "hashBatch first element matches the known test vector" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm.deinit();

    const inputs = [_][]const u8{ input, "another input" };
    const batch = try randomx.hashBatch(vm, &inputs, allocator);
    defer allocator.free(batch);

    try std.testing.expectEqual(@as(usize, 2), batch.len);
    try std.testing.expectEqualSlices(u8, &expected, &batch[0]);
}
