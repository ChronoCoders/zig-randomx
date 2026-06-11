# zig-randomx

Zig wrapper for the RandomX proof-of-work algorithm. Exposes a clean Zig API over
the RandomX C library with explicit error handling, allocator-aware types, and zero
C calls outside the binding layer.

## Requirements

- Zig 0.13.0
- Linux x86-64

No system C/C++ toolchain or CMake is required: `build.zig` compiles the vendored
RandomX sources directly with Zig's bundled clang and links libc/libc++.

## Build

```sh
git clone --recursive https://github.com/ChronoCoders/zig-randomx.git
cd zig-randomx
zig build
```

## Test

```sh
zig build test
```

All 20 tests must pass.

## API

```zig
const rx = @import("zig-randomx");

var cache = try rx.Cache.init(allocator, rx.recommendedFlags(), "my-key");
defer cache.deinit();

var vm = try rx.Vm.init(allocator, rx.recommendedFlags(), cache);
defer vm.deinit();

const h = rx.hash(vm, "input data");
```

Fast mode (higher throughput, requires ~2.18 GiB RAM):

```zig
var dataset = try rx.Dataset.init(allocator, rx.recommendedFlags());
defer dataset.deinit();
dataset.fill(cache, 0, rx.Dataset.itemCount());

var vm = try rx.Vm.initFast(allocator, rx.recommendedFlags(), dataset);
defer vm.deinit();
```

Initializing the full dataset on a single thread is slow. `Dataset.fillParallel`
splits the item range across N threads writing to non-overlapping ranges (no locks).
Pass 0 for the thread count to auto-detect the CPU count:

```zig
var dataset = try rx.Dataset.init(allocator, rx.recommendedFlags());
defer dataset.deinit();
try dataset.fillParallel(cache, 0, allocator);

var vm = try rx.Vm.initFast(allocator, rx.recommendedFlags(), dataset);
defer vm.deinit();
```

## Benchmark

Measured on WSL2 Ubuntu, Ryzen 9 5900X, JIT + AES-NI + AVX2 (flags 0x6a):

```sh
zig build -Doptimize=ReleaseFast
./zig-out/bin/bench --seconds 30 --threads 0 --key ferrous
```

```
mode:       light
duration:   30s
hashrate:   23.9 h/s

mode:       fast
threads:    24
init:       2.6s
duration:   30s
hashrate:   187.9 h/s
```

Fast mode is ~8x light mode. Native Linux bare-metal numbers will be higher.

The `--threads` flag controls how many threads initialize the dataset (default 0,
auto-detect). Fast mode reports the thread count and dataset init time.

## License

MIT. The vendored RandomX library under `vendor/randomx` retains its own
BSD-3-Clause license.
