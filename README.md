# hash-zig

[![CI](https://github.com/ch4r10t33r/hash-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/ch4r10t33r/hash-zig/actions/workflows/ci.yml)
[![Zig](https://img.shields.io/badge/zig-0.14.1-orange.svg)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A high-performance Zig implementation of hash-based signatures using **Poseidon2** with **exact compatibility** with the [hash-sig](https://github.com/b-wagn/hash-sig) Rust implementation. Implements **Generalized XMSS** signatures with Winternitz OTS.

## ✨ Features

- ✅ **Rust-Compatible**: Exact match with [hash-sig](https://github.com/b-wagn/hash-sig) implementation
- ✅ **Poseidon2 KoalaBear**: Width=16, external_rounds=8, internal_rounds=20, sbox=3
- ✅ **128-bit Post-Quantum Security**: Resistant to quantum attacks
- ✅ **Winternitz OTS**: w=8 (22 chains of length 256)
- ✅ **Flexible Lifetimes**: 2^10 to 2^32 signatures per keypair
- ✅ **Arena Allocator Safe**: Works correctly with any allocator type
- ✅ **Pure Zig**: Zero dependencies, fully type-safe

## 🚀 Quick Start

```zig
const std = @import("std");
const hash_zig = @import("hash-zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize with lifetime_2_10 (1,024 signatures)
    const params = hash_zig.Parameters.init(.lifetime_2_10);
    var sig_scheme = try hash_zig.HashSignature.init(allocator, params);
    defer sig_scheme.deinit();

    // Generate keypair
    var seed: [32]u8 = undefined;
    std.crypto.random.bytes(&seed);
    var keypair = try sig_scheme.generateKeyPair(allocator, &seed, 0, 0);
    defer keypair.deinit(allocator);

    // Sign a message
    const message = "Hello, hash-based signatures!";
    var rng_seed: [32]u8 = undefined;
    std.crypto.random.bytes(&rng_seed);
    var signature = try sig_scheme.sign(allocator, message, &keypair.secret_key, 0, &rng_seed);
    defer signature.deinit(allocator);

    // Verify signature
    const is_valid = try sig_scheme.verify(allocator, message, signature, &keypair.public_key);
    std.debug.print("Signature valid: {}\n", .{is_valid});
}
```

## 📦 Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .@"hash-zig" = .{
        .url = "https://github.com/ch4r10t33r/hash-zig/archive/refs/tags/v1.0.1.tar.gz",
        .hash = "...", // zig will provide this
    },
},
```

In your `build.zig`:

```zig
const hash_zig_dep = b.dependency("hash-zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("hash-zig", hash_zig_dep.module("hash-zig"));
```

## 📊 Performance

Benchmarked on **Apple M2 (8 cores)** with Zig 0.14.1, `-O ReleaseFast`:

### Lifetime 2^10 (1,024 signatures)

| Operation | Time | Complexity |
|-----------|------|------------|
| **Key Generation** | 166 seconds | O(n) |
| **Sign** | ~370 ms | O(log n) |
| **Verify** | ~93 ms | O(log n) |

### Key Sizes

| Component | Size | Description |
|-----------|------|-------------|
| **Public Key** | 32 bytes | Merkle root only |
| **Secret Key** | ~65 KB | PRF key + full tree (2047 nodes) |
| **Signature** | ~2.4 KB | Auth path + OTS signature + randomness |

### Notes

- Key generation uses parallel workers (scales with CPU cores)
- Sign/Verify times constant across all lifetimes (only depend on tree height)
- Full Merkle tree stored for fast signing (auth path lookup)
- PRF-based: OTS keys derived on-demand during signing

## 🔧 Configuration

Available key lifetimes:

```zig
.lifetime_2_10  // 2^10 = 1,024 signatures
.lifetime_2_16  // 2^16 = 65,536 signatures
.lifetime_2_18  // 2^18 = 262,144 signatures
.lifetime_2_20  // 2^20 = 1,048,576 signatures
.lifetime_2_28  // 2^28 = 268,435,456 signatures
.lifetime_2_32  // 2^32 = 4,294,967,296 signatures
```

Initialize parameters:

```zig
// Poseidon2 (default, Rust-compatible)
const params = hash_zig.Parameters.init(.lifetime_2_16);

// SHA3-256 (alternative)
const params_sha3 = hash_zig.Parameters.initWithSha3(.lifetime_2_16);
```

## 🔒 Security Considerations

### ⚠️ Critical: State Management

**This library does NOT track used signature indices.** Your application MUST:

1. ✅ Track the next available epoch/index (0 to lifetime-1)
2. ✅ Persist state BEFORE signing
3. ✅ Never reuse an index (security risk!)
4. ✅ Generate new keypair before exhausting lifetime

```zig
// Example: Safe state management
fn signMessage(db: *Database, sig: *HashSignature, msg: []const u8, sk: *SecretKey) !Signature {
    // 1. Get next index
    const epoch = try db.getNextEpoch();
    
    // 2. Persist BEFORE signing
    try db.saveEpoch(epoch + 1);
    try db.flush();
    
    // 3. Safe to sign
    var rng_seed: [32]u8 = undefined;
    std.crypto.random.bytes(&rng_seed);
    return sig.sign(allocator, msg, sk, epoch, &rng_seed);
}
```

### Security Properties

- ✅ **Post-quantum secure** (128-bit security)
- ✅ **Forward secure** (old signatures remain valid if key compromised)
- ⚠️ **Stateful** (requires index tracking - YOUR responsibility!)
- ⚠️ **One-time per index** (never reuse an epoch)

## 🧪 Testing

```bash
# Run all tests
zig build test

# Run only Rust compatibility tests (fast)
zig build test-rust-compat

# Run linter
zig build lint

# Build library
zig build

# Run examples
zig build example
```

## 📚 API Reference

### Key Structures

```zig
// Public Key (32 bytes + parameters)
pub const PublicKey = struct {
    root: []u8,              // Merkle root (32 bytes)
    parameter: Parameters,   // Hash function config
};

// Secret Key (PRF key + full tree)
pub const SecretKey = struct {
    prf_key: [32]u8,         // For OTS key derivation
    tree: [][]u8,            // Full Merkle tree nodes
    tree_height: u32,
    parameter: Parameters,
    activation_epoch: u64,   // First valid epoch
    num_active_epochs: u64,  // Number of valid epochs
};

// Signature
pub const Signature = struct {
    epoch: u64,              // Signature index
    auth_path: [][]u8,       // Merkle authentication path
    rho: [32]u8,            // Encoding randomness
    hashes: [][]u8,         // OTS signature
};
```

### Main Functions

```zig
// Initialize
var sig_scheme = try hash_zig.HashSignature.init(allocator, params);
defer sig_scheme.deinit();

// Generate keypair
var keypair = try sig_scheme.generateKeyPair(allocator, &seed, 0, 0);
defer keypair.deinit(allocator);

// Sign
var signature = try sig_scheme.sign(allocator, message, &keypair.secret_key, epoch, &rng_seed);
defer signature.deinit(allocator);

// Verify
const is_valid = try sig_scheme.verify(allocator, message, signature, &keypair.public_key);
```

## 🔗 Related Projects

- **Rust Reference**: [hash-sig](https://github.com/b-wagn/hash-sig) - Reference implementation
- **Benchmarks**: [hash-sig-benchmarks](https://github.com/ch4r10t33r/hash-sig-benchmarks) - Performance comparison
- **Paper**: [Generalized XMSS Framework](https://eprint.iacr.org/2025/055.pdf)
- **Poseidon2**: [Specification](https://eprint.iacr.org/2023/323.pdf)

## 📄 License

Apache License 2.0 - see [LICENSE](LICENSE) file.

## ⚠️ Disclaimer

**This is a prototype implementation for research and experimentation.**

- ❌ NOT audited
- ❌ NOT for production use
- ✅ Educational and research purposes only

**Your application MUST implement proper state management to prevent signature index reuse.**

---

Made with ❤️ in Zig
