const std = @import("std");
const alloc = std.heap.smp_allocator;
const constants = @import("constants.zig");
const crypt = @import("../util/crypt.zig");
const heuristics = @import("../util/heuristics.zig");
const Nkey392 = @import("../util/keynum.zig").Nkey392;
const decrypt = crypt.decrypt;
const extract_key = crypt.extract_key;

pub const Command = union(enum) {
	idup: struct { i: u8 },
	kdup: struct { k: u8 },
	iadd: struct { dst: u8, src: u8 },
	imul: struct { dst: u8, src: u8 },
	kkadd: struct { dst: u8, src: u8 },
	kkmul: struct { dst: u8, src: u8 },
	expand: struct { i: u8 },
	// what about geometric series expand?
	// collapse? (idk base10 str concat of key)
	// sum?
	kdecrypt: struct { dst: u8, key: u8 },
	ddecrypt: struct { key: u8 },
	repeat: struct { rep_count: u8, end: u8 },
};

const Frame = struct {
	loop_start: u8,
	loop_end: u8,
	repetitions_left: u8,
	ivar: u8,
	kvars: u8,
};

pub const Interp = struct {
	ivars: std.ArrayList(Nkey392),
	kvars: std.ArrayList([]Nkey392), // TODO: consider ArenaAllocator for kvars
	loopstack: std.ArrayList(Frame),
	data: []u8,

	pub fn init() Interp {
		var iv = std.ArrayList(Nkey392).initCapacity(alloc, 32) catch @panic("OOM");
		iv.appendAssumeCapacity(.{.n=1});
		iv.appendAssumeCapacity(.{.n=constants.N0});
		iv.appendAssumeCapacity(.{.n=constants.N1});
		var kv = std.ArrayList([]Nkey392).initCapacity(alloc, 32) catch @panic("OOM");
		kv.appendAssumeCapacity(alloc.dupe(Nkey392, &constants.K0E) catch @panic("OOM"));
		kv.appendAssumeCapacity(alloc.alloc(Nkey392, constants.K0_LEN) catch @panic("OOM"));
		for (0.., kv.items[1]) |i, *k| {
			k.n = i;
		}
		return .{.ivars=iv, .kvars=kv,
			.loopstack=std.ArrayList(Frame).initCapacity(alloc, 16) catch @panic("OOM"),
			.data=alloc.dupe(u8, constants.DATA) catch @panic("OOM")};
	}
	pub fn deinit(self: *Interp) void {
		self.ivars.deinit(alloc);
		for (self.kvars) |k| {
			alloc.free(k);
		}
		self.kvars.deinit(alloc);
		self.loopstack.deinit(alloc);
		alloc.free(self.data);
	}
	pub fn reset(self: *Interp) void {
		for (self.kvars.items[2..]) |k| {
			alloc.free(k);
		}
		self.kvars.shrinkRetainingCapacity(2);
		@memcpy(self.kvars.items[0], &constants.K0E);
		for (0.., self.kvars.items[1]) |i, *k| {
			k.n = i;
		}
		self.ivars.shrinkRetainingCapacity(3);
		self.ivars.items[0].n = 1;
		self.ivars.items[1].n = constants.N0;
		self.ivars.items[2].n = constants.N1;
		self.loopstack.clearRetainingCapacity();
		@memcpy(self.data, constants.DATA);
	}
	fn last_ivar(self: *Interp) *Nkey392 { return &self.ivars.items[self.ivars.items.len-1]; }
	fn ivar(self: *Interp, i: u8) *Nkey392 { return &self.ivars.items[@intCast(i)]; }
	fn kvar(self: *Interp, i: u8) []Nkey392 { return self.kvars.items[@intCast(i)]; }
	pub fn do_command(self: *Interp, cmd: Command) void {
		switch (cmd) {
		.idup => |a| self.ivars.appendAssumeCapacity(self.ivar(a.i).*),
		.kdup => |a| self.kvars.appendAssumeCapacity(alloc.dupe(Nkey392, self.kvar(a.k)) catch @panic("OOM")),
		.iadd => |a| self.ivar(a.dst).add_self(self.ivar(a.src)),
		.imul => |a| self.ivar(a.dst).mul_self(self.ivar(a.src)),
		.kkadd => |a| {
			for (self.kvar(a.dst), self.kvar(a.src)) |*kd, *ks| {
				kd.add_self(ks);
			}
		},
		.kkmul => |a| {
			for (self.kvar(a.dst), self.kvar(a.src)) |*kd, *ks| {
				kd.mul_self(ks);
			}
		},
		.expand => |a| {
			const nk = alloc.alloc(Nkey392, constants.K0_LEN) catch @panic("OOM");
			@memset(nk, self.ivar(a.i).*);
			self.kvars.appendAssumeCapacity(nk);
		},
		.kdecrypt => |a| decrypt(Nkey392, self.kvar(a.dst), self.kvar(a.key)),
		.ddecrypt => |a| decrypt(u8, self.data, self.kvar(a.key)),
		.repeat => unreachable,
		}
	}
	fn run_program(self: *Interp, cmd: []const Command) void {
		var ip: usize = 0;
		while (ip < cmd.len) {
			if (self.loopstack.items.len > 0) {
				const loop = &self.loopstack.items[self.loopstack.items.len-1];
				if (ip == loop.loop_end) {
					loop.repetitions_left -= 1;
					for (self.kvars.items[@intCast(loop.kvars)..]) |k| {
						alloc.free(k);
					}
					self.kvars.shrinkRetainingCapacity(@intCast(loop.kvars));
					if (loop.repetitions_left < 1) {
						//std.debug.print("\x1b[91m[loop end]  ip {}, {} ivs, {} kvs\x1b[0m\n",
							//.{ip, self.ivars.items.len, self.kvars.items.len});
						self.ivars.shrinkRetainingCapacity(@intCast(loop.ivar));
						_ = self.loopstack.pop();
						continue;
					}
					//std.debug.print("\x1b[91m[loop cont] ip {}, {} ivs, {} kvs\x1b[0m\n",
						//.{ip, self.ivars.items.len, self.kvars.items.len});
					ip = loop.loop_start + 1;
					self.ivar(loop.ivar).n += 1;
					self.ivars.shrinkRetainingCapacity(@intCast(loop.ivar+1));
					continue;
				}
			}
			if (cmd[ip] == .repeat) {
				//std.debug.print("\x1b[91m[repeat]    ip {}, {} ivs, {} kvs\x1b[0m\n",
					//.{ip, self.ivars.items.len, self.kvars.items.len});
				const r = cmd[ip].repeat;
				var reps = self.ivar(r.rep_count).n;
				if (reps >= 40 or reps < 1)
					reps = 1;
				self.loopstack.appendAssumeCapacity(.{.loop_start=@intCast(ip),
					.loop_end=r.end, .repetitions_left=@intCast(reps),
					.ivar=@intCast(self.ivars.items.len),
					.kvars=@intCast(self.kvars.items.len)});
				self.ivars.appendAssumeCapacity(.{.n=1});
			} else {
				//std.debug.print("\x1b[91m[command]   ip {}, {} ivs, {} kvs\x1b[0m\n",
					//.{ip, self.ivars.items.len, self.kvars.items.len});
				self.do_command(cmd[ip]);
			}
			ip += 1;
		}
	}
};

pub fn generate(seed: u64, cmds: []Command) void {
	var rand: std.Random.Xoshiro256 = .init(seed);
	var vcounts = std.ArrayList(struct{i: u8, k: u8, end: u8}).initCapacity(alloc, 4) catch @panic("OOM");
	vcounts.appendAssumeCapacity(.{.i=3,.k=2, .end=0xff});
	for (0.., cmds) |i, *c| {
		const selection = (rand.next() >> 6) % (if (vcounts.items.len < 3) @as(u8, 10) else @as(u8, 9));
		while (i == vcounts.getLast().end) {
			_ = vcounts.pop();
		}
		if (i == cmds.len-1) {
			c.* = .{.ddecrypt=.{.key=vcounts.getLast().k-1}};
			continue;
		}
		switch (selection) {
		0 => {
			c.* = .{.idup=.{.i=@intCast(rand.next()%vcounts.getLast().i)}};
			vcounts.items[vcounts.items.len-1].i += 1;
		},
		1 => {
			c.* = .{.kdup=.{.k=@intCast(rand.next()%vcounts.getLast().k)}};
			vcounts.items[vcounts.items.len-1].k += 1;
		},
		2 => {
			c.* = .{.iadd=.{
				.dst=@intCast(rand.next()%vcounts.getLast().i),
				.src=@intCast(rand.next()%vcounts.getLast().i)
			}};
		},
		3 => {
			c.* = .{.imul=.{
				.dst=@intCast(rand.next()%vcounts.getLast().i),
				.src=@intCast(rand.next()%vcounts.getLast().i)
			}};
		},
		4 => {
			c.* = .{.kkadd=.{
				.dst=@intCast(rand.next()%vcounts.getLast().k),
				.src=@intCast(rand.next()%vcounts.getLast().k)
			}};
		},
		5 => {
			c.* = .{.kkmul=.{
				.dst=@intCast(rand.next()%vcounts.getLast().k),
				.src=@intCast(rand.next()%vcounts.getLast().k)
			}};
		},
		6 => {
			c.* = .{.expand=.{.i=@intCast(rand.next()%vcounts.getLast().i)}};
			vcounts.items[vcounts.items.len-1].k += 1;
		},
		7 => {
			c.* = .{.kdecrypt=.{
				.dst=@intCast(rand.next()%vcounts.getLast().k),
				.key=@intCast(rand.next()%vcounts.getLast().k)
			}};
		},
		8 => {
			c.* = .{.ddecrypt=.{.key=@intCast(rand.next()%vcounts.getLast().k)}};
		},
		9 => {
			const end: u8 = @intCast((rand.next()%(cmds.len-i-1))+i+2);
			c.* = .{.repeat=.{.rep_count=@intCast(rand.next()%vcounts.getLast().i), .end=end}};
			vcounts.appendAssumeCapacity(.{.k=vcounts.getLast().k,
				.i=vcounts.getLast().i+1,.end=end});
		},
		else => unreachable,
		}
	}
}
pub fn print_cmds(seed: u64, cmds: []Command) void {
	std.debug.print("\x1b[90m[seed \x1b[93m{}\x1b[90m]\x1b[0m\n", .{seed});
	const indenter = "\t\t\t\t";
	var indent: u8 = 0;
	var repeat_ends: u256 = 0;
	for (0.., cmds) |i, c| {
		if ((repeat_ends >> @intCast(i) & 1) != 0) {
			indent -= 1;
		}
		switch (c) {
		.idup => |a| std.debug.print("\x1b[96m{s}idup %{}\x1b[0m\n",
			.{indenter[0..indent], a.i}),
		.kdup => |a| std.debug.print("\x1b[96m{s}kdup K{}\x1b[0m\n",
			.{indenter[0..indent], a.k}),
		.iadd => |a| std.debug.print("\x1b[94m{s}%{} += %{}\x1b[0m\n",
			.{indenter[0..indent], a.dst, a.src}),
		.imul => |a| std.debug.print("\x1b[94m{s}%{} *= %{}\x1b[0m\n",
			.{indenter[0..indent], a.dst, a.src}),
		.kkadd => |a| std.debug.print("\x1b[94m{s}K{} += K{}\x1b[0m\n",
			.{indenter[0..indent], a.dst, a.src}),
		.kkmul => |a| std.debug.print("\x1b[94m{s}K{} *= K{}\x1b[0m\n",
			.{indenter[0..indent], a.dst, a.src}),
		.expand => |a| std.debug.print("\x1b[96m{s}expand %{}\x1b[0m\n",
			.{indenter[0..indent], a.i}),
		.kdecrypt => |a| std.debug.print("\x1b[92m{s}kdecrypt K{} using K{}\x1b[0m\n",
			.{indenter[0..indent], a.dst, a.key}),
		.ddecrypt => |a| std.debug.print("\x1b[92m{s}ddecrypt data using K{}\x1b[0m\n",
			.{indenter[0..indent], a.key}),
		.repeat => |a| {
			repeat_ends |= @as(u256, 1) << a.end;
			std.debug.print("\x1b[1m{s}repeat %{} times\x1b[90m end at {}\x1b[0m\n",
				.{indenter[0..indent], a.rep_count, a.end});
			indent += 1;
		}
		}
	}
}
pub fn attempt(interp: *Interp, seed: u64, cmds: []Command) bool {
	interp.reset();
	generate(seed, cmds);
	//print_cmds(seed, cmds);
	interp.run_program(cmds);
	if (!std.ascii.isLower(interp.data[0])) return false;
	if (!std.ascii.isLower(interp.data[1])) return false;
	if (std.ascii.isUpper(interp.data[2])) return false;
	//if (std.ascii.isUpper(interp.data[3])) return false;
	//if (std.ascii.isUpper(interp.data[4])) return false;
	if (interp.data[constants.DATA_LEN-1] != ')') return false;
	var completed: u8 = 0;
	for (interp.data) |c| {
		if (c == ' ') {
			completed = 1;
		} else {
			switch (completed) {
			0 => {},
			1 => completed = if (c == 'D') 2 else 0,
			2 => completed = if (c == 'A') 3 else 0,
			3 => completed = if (c == 'T') 4 else 0,
			4 => completed = if (c == 'A') 5 else 0,
			5 => {
				if (c == '(')
					return true;
				completed = 0;
			},
			else => unreachable
			}
		}
		if (c == '(' or c == ')')
			return false;
	}
	unreachable;
}
