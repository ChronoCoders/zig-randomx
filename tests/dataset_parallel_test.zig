const std = @import("std");
const randomx = @import("randomx");

const key = "parallel dataset key\x00";
const input = "parallel dataset input\x00";

fn fastHash(allocator: std.mem.Allocator, flags: randomx.Flags, parallel: bool) !randomx.Hash {
    var cache = try randomx.Cache.init(allocator, flags, key);
    defer cache.deinit();

    var dataset = try randomx.Dataset.init(allocator, flags);
    defer dataset.deinit();

    if (parallel) {
        try dataset.fillParallel(cache, 2, allocator);
    } else {
        dataset.fill(cache, 0, randomx.Dataset.itemCount());
    }

    var vm = try randomx.Vm.initFast(allocator, flags, dataset);
    defer vm.deinit();

    return randomx.hash(vm, input);
}

test "single-thread fill and parallel fill produce identical hashes" {
    const allocator = std.testing.allocator;
    const flags = randomx.recommendedFlags();

    const single = try fastHash(allocator, flags, false);
    const parallel = try fastHash(allocator, flags, true);

    try std.testing.expectEqualSlices(u8, &single, &parallel);
}
