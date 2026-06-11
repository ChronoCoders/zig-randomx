const std = @import("std");
const randomx = @import("randomx");

const Config = struct {
    seconds: u64,
    key: []const u8,
    threads: usize,
};

const ParseError = error{
    MissingValue,
    UnknownArgument,
    InvalidNumber,
};

const Result = struct {
    hashes: u64,
    elapsed_ns: u64,
};

fn parseArgs(args: [][:0]u8) ParseError!Config {
    var config = Config{ .seconds = 10, .key = "benchmark", .threads = 0 };
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--seconds")) {
            i += 1;
            if (i >= args.len) return ParseError.MissingValue;
            config.seconds = std.fmt.parseInt(u64, args[i], 10) catch return ParseError.InvalidNumber;
        } else if (std.mem.eql(u8, arg, "--key")) {
            i += 1;
            if (i >= args.len) return ParseError.MissingValue;
            config.key = args[i];
        } else if (std.mem.eql(u8, arg, "--threads")) {
            i += 1;
            if (i >= args.len) return ParseError.MissingValue;
            config.threads = std.fmt.parseInt(usize, args[i], 10) catch return ParseError.InvalidNumber;
        } else {
            return ParseError.UnknownArgument;
        }
    }
    return config;
}

fn runBench(vm: randomx.Vm, seconds: u64) error{Timer}!Result {
    const duration_ns = seconds * std.time.ns_per_s;
    var timer = std.time.Timer.start() catch return error.Timer;
    var hashes: u64 = 0;
    var input = [_]u8{0} ** 76;
    while (true) {
        std.mem.writeInt(u64, input[0..8], hashes, .little);
        const out = randomx.hash(vm, &input);
        std.mem.doNotOptimizeAway(out);
        hashes += 1;
        if (timer.read() >= duration_ns) break;
    }
    return .{ .hashes = hashes, .elapsed_ns = timer.read() };
}

fn printResult(writer: anytype, mode_name: []const u8, seconds: u64, result: Result) !void {
    const elapsed_s = @as(f64, @floatFromInt(result.elapsed_ns)) / std.time.ns_per_s;
    const rate = @as(f64, @floatFromInt(result.hashes)) / elapsed_s;
    try writer.print("mode:       {s}\n", .{mode_name});
    try writer.print("duration:   {d}s\n", .{seconds});
    try writer.print("hashes:     {d}\n", .{result.hashes});
    try writer.print("hashrate:   {d:.1} h/s\n", .{rate});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const config = try parseArgs(args);

    const stdout = std.io.getStdOut().writer();
    const flags = randomx.recommendedFlags();
    try std.io.getStdErr().writer().print("flags:      0x{x}\n\n", .{flags});

    var cache = try randomx.Cache.init(allocator, flags, config.key);
    defer cache.deinit();

    {
        var vm = try randomx.Vm.init(allocator, flags, cache);
        defer vm.deinit();
        const result = try runBench(vm, config.seconds);
        try printResult(stdout, "light", config.seconds, result);
    }

    try stdout.writeAll("\n");

    {
        var threads = config.threads;
        if (threads == 0) threads = std.Thread.getCpuCount() catch 1;

        var dataset = try randomx.Dataset.init(allocator, flags);
        defer dataset.deinit();

        var init_timer = std.time.Timer.start() catch return error.Timer;
        try dataset.fillParallel(cache, threads, allocator);
        const init_s = @as(f64, @floatFromInt(init_timer.read())) / std.time.ns_per_s;

        var vm = try randomx.Vm.initFast(allocator, flags, dataset);
        defer vm.deinit();
        const result = try runBench(vm, config.seconds);

        const elapsed_s = @as(f64, @floatFromInt(result.elapsed_ns)) / std.time.ns_per_s;
        const rate = @as(f64, @floatFromInt(result.hashes)) / elapsed_s;
        try stdout.print("mode:       fast\n", .{});
        try stdout.print("threads:    {d}\n", .{threads});
        try stdout.print("init:       {d:.1}s\n", .{init_s});
        try stdout.print("duration:   {d}s\n", .{config.seconds});
        try stdout.print("hashes:     {d}\n", .{result.hashes});
        try stdout.print("hashrate:   {d:.1} h/s\n", .{rate});
    }
}
