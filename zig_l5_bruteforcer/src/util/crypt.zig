const std = @import("std");
const Nkey392 = @import("keynum.zig").Nkey392;

pub fn extract_key(len: comptime_int, strkey: [len]u8) [len]Nkey392 {
	var out: [len]Nkey392 = undefined;
	for (0..len) |i| {
		out[i] = .{.n=strkey[i]-64};
	}
	return out;
}
pub fn decrypt(T: anytype, data: []T, key: []const Nkey392) void {
	var at: Nkey392 = .{.n = 0};
	var key_at: u32 = 0;
	const datalen32: u32 = @intCast(data.len);
	for (0..data.len) |i| {
		const index32: u32 = @intCast(i);
		at.add_self(&key[key_at]);
		key_at = (key_at + 1) % @as(u32, @intCast(key.len));
		const atr = at.trunc_to(datalen32-index32)+index32;
		const selected = data[@intCast(atr)];
		std.mem.copyBackwards(T, data[i+1..@intCast(atr+1)], data[i..@intCast(atr)]);
		data[i] = selected;
	}
}

test "decrypt previous levels" {
	const data = @import("data.zig");

	const K1: [1]Nkey392 = .{.{.n=17}};
	const K2: [35]Nkey392 = extract_key(35, "HUMANSCANTSOLVETHISSOBETTERSTOPHERE".*);
	const K3: [5]Nkey392 = extract_key(5, "EILLE".*);
	const K4: [7]Nkey392 = extract_key(7, "XDYOYOY".*);

	const D1 = try std.testing.allocator.dupe(u8, data.level1.data);
	defer std.testing.allocator.free(D1);
	const D2 = try std.testing.allocator.dupe(u8, data.level2.data);
	defer std.testing.allocator.free(D2);
	const D3 = try std.testing.allocator.dupe(u8, data.level3.data);
	defer std.testing.allocator.free(D3);
	const D4 = try std.testing.allocator.dupe(u8, data.level4.data);
	defer std.testing.allocator.free(D4);


	// the keys are small and Nkey392 mod is huge so it shouldn't break anything
	decrypt(u8, D1, &K1);
	decrypt(u8, D2, &K2);
	decrypt(u8, D3, &K3);
	decrypt(u8, D4, &K4);

	try std.testing.expectEqualStrings(data.level2.text, D1);
	try std.testing.expectEqualStrings(data.level3.text, D2);
	try std.testing.expectEqualStrings(data.level4.text, D3);
	try std.testing.expectEqualStrings(data.level5.text, D4);

	std.debug.print("decrypt previous levels test passed!\n", .{});
}
