//! SSZ-compatible wrappers for Poseidon2 hash functions
//! Provides SHA256-like API for use with SSZ merkleization

const poseidon2 = @import("../poseidon2/root.zig");

pub const PoseidonHasher = @import("poseidon_wrapper.zig").PoseidonHasher;

// Pre-configured SSZ hasher using Poseidon2 KoalaBear24 Plonky3 (DEFAULT)
// Uses 24-bit limb packing: 64 bytes → 22 limbs, single permutation
pub const SszHasher = PoseidonHasher(poseidon2.Poseidon2KoalaBear24Plonky3);

// Import test modules to ensure they run
test {
    _ = @import("poseidon_wrapper.zig");
    _ = @import("poseidon_plonky3_validation.zig");
}
