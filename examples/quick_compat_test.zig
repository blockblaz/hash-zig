//! Quick compatibility test with lifetime 2^10

const std = @import("std");
const hash_zig = @import("hash-zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🚀 Quick Compatibility Test (2^10)\n", .{});
    std.debug.print("=" ** 80 ++ "\n\n", .{});

    const params = hash_zig.Parameters.init(.lifetime_2_10);
    var hash_sig = try hash_zig.HashSignatureNative.init(allocator, params);
    defer hash_sig.deinit();

    var seed: [32]u8 = undefined;
    @memset(&seed, 0x42);

    const start = std.time.milliTimestamp();
    var keypair = try hash_sig.generateKeyPair(allocator, &seed, 0, 1024);
    defer keypair.deinit(allocator);
    const elapsed = std.time.milliTimestamp() - start;

    std.debug.print("✅ Generated in {d}ms\n", .{elapsed});
    std.debug.print("Root (first element): {d} (0x{x:0>8})\n\n", .{ keypair.public_key.root[0].toU32(), keypair.public_key.root[0].toU32() });

    // Convert root to bytes for SHA3
    var root_bytes = try allocator.alloc(u8, keypair.public_key.root.len * 4);
    defer allocator.free(root_bytes);
    for (keypair.public_key.root, 0..) |elem, i| {
        const val = elem.toU32();
        std.mem.writeInt(u32, root_bytes[i * 4 ..][0..4], val, .little);
    }
    var hasher = std.crypto.hash.sha3.Sha3_256.init(.{});
    hasher.update(root_bytes);
    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    std.debug.print("Root SHA3-256: ", .{});
    for (hash) |byte| std.debug.print("{x:0>2}", .{byte});
    std.debug.print("\n\n", .{});
}
