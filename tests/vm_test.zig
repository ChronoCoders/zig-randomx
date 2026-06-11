const std = @import("std");
const randomx = @import("randomx");

const key = "RandomX example key\x00";
const input = "RandomX example input\x00";

test "VM creation and destruction" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    vm.deinit();
}

test "double hash of the same input is consistent" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm.deinit();

    const first = randomx.hash(vm, input);
    const second = randomx.hash(vm, input);
    try std.testing.expectEqualSlices(u8, &first, &second);
}

test "distinct inputs produce distinct hashes" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm.deinit();

    const a = randomx.hash(vm, input);
    const b = randomx.hash(vm, "different input");
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}

test "two independent VMs from the same cache agree" {
    const allocator = std.testing.allocator;

    var cache = try randomx.Cache.init(allocator, randomx.flag_default, key);
    defer cache.deinit();

    var vm1 = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm1.deinit();
    var vm2 = try randomx.Vm.init(allocator, randomx.flag_default, cache);
    defer vm2.deinit();

    const h1 = randomx.hash(vm1, input);
    const h2 = randomx.hash(vm2, input);
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}
