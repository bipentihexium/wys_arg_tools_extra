const std = @import("std");
const alloc = std.heap.smp_allocator;
const solver = @import("solver");
const decrypt = solver.decrypt;
const extract_key = solver.extract_key;
const Nkey392 = solver.Nkey392;

var print_mutex: std.Thread.Mutex = .{};
fn bruteforce(seed0: u64, cmdc: usize) void {
	var counter: u64 = 0;
	var interp: solver.search.Interp = .init();
	defer interp.deinit();
	const cmds: []solver.search.Command = alloc.alloc(solver.search.Command, cmdc) catch @panic("OOM");
	defer alloc.free(cmds);
	while (true) {
		const seed = seed0 + counter;
		if (solver.search.attempt(&interp, seed, cmds)) {
			print_mutex.lock();
			std.debug.print("----------- hit ------------\n", .{});
			solver.search.print_cmds(seed, cmds);
			std.debug.print("result [\x1b[94m{s}\x1b[0m]\n", .{interp.data});
			print_mutex.unlock();
		}
		counter += 1;
		if (counter & 0xfffff == 0) {
			print_mutex.lock();
			std.debug.print("\x1b[90mthread with seed0 {} has done {} attempts\x1b[0m\n", .{seed0, counter});
			print_mutex.unlock();
		}
	}
}

pub fn main() !void {
	var pool: std.Thread.Pool = undefined;
	try pool.init(.{.allocator=alloc, .n_jobs=6});
	defer pool.deinit();
	var wg: std.Thread.WaitGroup = .{};
	for (0..6) |c| {
		pool.spawnWg(&wg, bruteforce, .{@as(u64, c << 48), 12});
	}
	//pool.spawnWg(&wg, bruteforce, .{@as(u64, 42 << 56), 8});
	wg.wait();
}
