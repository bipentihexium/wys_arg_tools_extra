const std = @import("std");
const Nkey392 = @import("keynum.zig").Nkey392;

// uhh, probably not worth it with NK392 numbers :/ (didn't check though)
// also untested
pub fn terminator(terminator_count: comptime_int, data_length: comptime_int,
	terminators: [terminator_count]u32, key: []const Nkey392) bool {
	var key_at: u32 = 0;
	var hits_left: u32 = terminator_count;
	for (0..data_length-1) |i| {
		const k = &key[key_at];
		// TODO: benchmark those two?
		key_at += 1;
		if (key_at == key.len) key_at = 0;
		//key_at = (key_at + 1) % key.len;
		const curr_data_length = data_length - i;
		for (terminators) |*term| {
			if (term == std.math.maxInt(u32)) continue;
			var new_pos_nk392: Nkey392 = .{.n=@intCast(term)};
			new_pos_nk392.add_self(k);
			term = new_pos_nk392.trunc_to(curr_data_length);
			if (term == 0) {
				term = std.math.maxInt(u32);
				if (hits_left <= 1)
					return true;
				hits_left -= 1;
			}
		}
	}
	return false;
}
// assumes key length >= 3
pub fn first3filter(data_length: comptime_int, data: []const u8, key: []const Nkey392) bool {
	var at: Nkey392 = key[0];
	const at0 = at.trunc_to(data_length);
	if (!std.ascii.isLower(data[at0])) return false;
	at.add_self(&key[1]);
	var at1 = at.trunc_to(data_length-1);
	if (at1 >= at0) at1 += 1;
	if (!std.ascii.isLower(data[at1])) return false;
	at.add_self(&key[2]);
	var at2 = at.trunc_to(data_length-2);
	if (at2 >= at0) at2 += 1;
	if (at2 >= at1) at2 += 1;
	if (at2 == at0) at2 += 1;
	if (std.ascii.isUpper(data[at2])) return false;
	//std.debug.print("[{c}][{c}][{c}]\n", .{data[at0], data[at1], data[at2]});
	return true;
}
// consumes data_copy
pub fn databeforeparens(data_copy: []u8, key: []const Nkey392) bool {
	// comparing against: " DATA("
	var completed: u8 = 0;
	var at: Nkey392 = .{.n = 0};
	var key_at: u32 = 0;
	const datalen32: u32 = @intCast(data_copy.len);
	for (0..data_copy.len) |i| {
		const index32: u32 = @intCast(i);
		at.add_self(&key[key_at]);
		key_at = (key_at + 1) % @as(u32, @intCast(key.len));
		const atr = at.trunc_to(datalen32-index32)+index32;
		const selected = data_copy[@intCast(atr)];
		std.mem.copyBackwards(u8, data_copy[i+1..@intCast(atr+1)], data_copy[i..@intCast(atr)]);
		if (selected == ' ') {
			completed = 1;
		} else {
			switch (completed) {
			0 => {},
			1 => completed = if (selected == 'D') 2 else 0,
			2 => completed = if (selected == 'A') 3 else 0,
			3 => completed = if (selected == 'T') 4 else 0,
			4 => completed = if (selected == 'A') 5 else 0,
			5 => {
				if (selected == '(')
					return true;
				completed = 0;
			},
			else => unreachable
			}
		}
		if (selected == '(' or selected == ')')
			return false;
	}
	unreachable;
}
