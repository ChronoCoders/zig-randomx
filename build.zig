const std = @import("std");

const randomx_root = "vendor/randomx/src";

const randomx_cpp_sources = [_][]const u8{
    "aes_hash.cpp",
    "bytecode_machine.cpp",
    "cpu.cpp",
    "dataset.cpp",
    "soft_aes.cpp",
    "vm_interpreted.cpp",
    "allocator.cpp",
    "assembly_generator_x86.cpp",
    "instruction.cpp",
    "randomx.cpp",
    "superscalar.cpp",
    "vm_compiled.cpp",
    "vm_interpreted_light.cpp",
    "blake2_generator.cpp",
    "instructions_portable.cpp",
    "virtual_machine.cpp",
    "vm_compiled_light.cpp",
    "jit_compiler_x86.cpp",
};

const randomx_c_sources = [_][]const u8{
    "argon2_ref.c",
    "argon2_core.c",
    "virtual_memory.c",
    "reciprocal.c",
    "blake2/blake2b.c",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "randomx",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path(randomx_root));

    const cpp_flags = [_][]const u8{ "-std=c++11", "-maes", "-fno-sanitize=all" };
    const c_flags = [_][]const u8{ "-maes", "-fno-sanitize=all" };

    inline for (randomx_cpp_sources) |src| {
        lib.addCSourceFile(.{
            .file = b.path(randomx_root ++ "/" ++ src),
            .flags = &cpp_flags,
        });
    }
    inline for (randomx_c_sources) |src| {
        lib.addCSourceFile(.{
            .file = b.path(randomx_root ++ "/" ++ src),
            .flags = &c_flags,
        });
    }

    lib.addCSourceFile(.{
        .file = b.path(randomx_root ++ "/argon2_ssse3.c"),
        .flags = &[_][]const u8{ "-maes", "-mssse3", "-fno-sanitize=all" },
    });
    lib.addCSourceFile(.{
        .file = b.path(randomx_root ++ "/argon2_avx2.c"),
        .flags = &[_][]const u8{ "-maes", "-mavx2", "-fno-sanitize=all" },
    });

    lib.addAssemblyFile(b.path(randomx_root ++ "/jit_compiler_x86_static.S"));

    lib.linkLibC();
    lib.linkLibCpp();

    const module = b.addModule("randomx", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.addIncludePath(b.path(randomx_root));
    module.linkLibrary(lib);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.addIncludePath(b.path(randomx_root));
    unit_tests.linkLibrary(lib);
    unit_tests.linkLibC();
    unit_tests.linkLibCpp();

    const hash_tests = b.addTest(.{
        .root_source_file = b.path("tests/hash_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    hash_tests.root_module.addImport("randomx", module);
    hash_tests.addIncludePath(b.path(randomx_root));
    hash_tests.linkLibrary(lib);
    hash_tests.linkLibC();
    hash_tests.linkLibCpp();

    const vm_tests = b.addTest(.{
        .root_source_file = b.path("tests/vm_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    vm_tests.root_module.addImport("randomx", module);
    vm_tests.addIncludePath(b.path(randomx_root));
    vm_tests.linkLibrary(lib);
    vm_tests.linkLibC();
    vm_tests.linkLibCpp();

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench.root_module.addImport("randomx", module);
    bench.addIncludePath(b.path(randomx_root));
    bench.linkLibrary(lib);
    bench.linkLibC();
    bench.linkLibCpp();
    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    run_bench.step.dependOn(b.getInstallStep());
    if (b.args) |bench_args| run_bench.addArgs(bench_args);
    const bench_step = b.step("bench", "Build and run the benchmark");
    bench_step.dependOn(&run_bench.step);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_hash_tests = b.addRunArtifact(hash_tests);
    const run_vm_tests = b.addRunArtifact(vm_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_hash_tests.step);
    test_step.dependOn(&run_vm_tests.step);

    b.installArtifact(lib);
}
