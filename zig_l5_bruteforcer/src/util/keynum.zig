const std = @import("std");

//fn big_lcm_392() u576 {
	//var out: u576 = 1;
	//for (1..393) |n| {
		//out = std.math.lcm(out, n);
	//}
	//return out;
//}
//pub const key_mod_392: u576 = big_lcm_392(); // has 566 bits
//zig has small comptime limits so python's result it is:
//>>> from math import lcm
//>>> lcm(*range(1,393))
pub const key_mod_392: u576 =
150297074242628609386929396433520251376084930365274714534308229042521928292663393687352048872896883342743557672991260779429923789704748472320306058299497464688269972384000;
//>>> lcm(*range(1,393)).bit_length() -> 566 
pub const Nkey392 = struct {
	n: u576,

	pub fn add_self(self: *Nkey392, b: *const Nkey392) void {
		self.n += b.n;
		if (self.n > key_mod_392) {
			self.n -= key_mod_392;
		}
	}
	pub fn double_self(self: *Nkey392) void {
		self.n <<= 1;
		if (self.n > key_mod_392) {
			self.n -= key_mod_392;
		}
	}
	pub fn mul_self(self: *Nkey392, b: *const Nkey392) void {
		self.n = @intCast((@as(u1152, @intCast(self.n)) * @as(u1152, @intCast(b.n))) % @as(u1152, @intCast(key_mod_392)));
	}
	pub fn square_self(self: *Nkey392) void {
		self.n = @rem(@as(u1152, @intCast(self.n)) * @as(u1152, @intCast(self.n)), @as(u1152, @intCast(key_mod_392)));
	}
	pub fn small_exp_self(self: *Nkey392, exp: u64) Nkey392 {
		var out: Nkey392 = .{.n=1};
		var exp_left = exp;
		while (exp_left > 1) {
			if ((exp_left & 1) > 0) {
				out.mul_self(self);
			}
			self.square_self();
			exp_left >>= 1;
		}
		if (exp_left > 0) {
			out.mul_self(&self);
		}
		self.n = out.n;
	}
	pub fn trunc_to(self: *Nkey392, mod: u32) u32 {
		self.n = @rem(self.n, @as(u576, @intCast(mod)));
		return @intCast(self.n);
	}
};
