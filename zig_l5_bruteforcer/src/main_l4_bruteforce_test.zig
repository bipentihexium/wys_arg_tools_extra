const std = @import("std");
const alloc = std.heap.smp_allocator;
const solver = @import("solver");
const decrypt = solver.decrypt;
const extract_key = solver.extract_key;
const Nkey392 = solver.Nkey392;

var print_mutex: std.Thread.Mutex = .{};
fn l4_bruteforce(starting_letter: u8) void {
	var key: [7]Nkey392 = extract_key(7, "AAAAAAA".*);
	key[0].n = @intCast(starting_letter-64);
	const data = alloc.dupe(u8, solver.level4.data) catch @panic("OOM");
	defer alloc.free(data);
	while (key[1].n < 27) {
		const first3 = solver.heuristics.first3filter(511, solver.level4.data, &key);
		if (first3) {
			if (solver.heuristics.databeforeparens(data, &key)) {
				@memcpy(data, solver.level4.data);
				decrypt(u8, data, &key);
				if (data[data.len-1] == ')') {
					print_mutex.lock();
					std.debug.print("hit: key \x1b[92m{any}\n\x1b[94m{s}\x1b[0m\n", .{key, data});
					print_mutex.unlock();
				}
			}
			@memcpy(data, solver.level4.data);
			var i: usize = 6;
			while (true): (i -= 1) {
				key[i].n += 1;
				if (key[i].n < 27)
					break;
				if (i == 1)
					break;
				key[i].n = 1;
			}
		} else {
			for (3..7) |i| { key[i].n = 1; }
			key[2].n += 1;
			if (key[2].n >= 27) {
				key[2].n = 1;
				key[1].n += 1;
			}
		}
	}
	print_mutex.lock();
	std.debug.print("\x1b[90mfinished for letter '{c}'\x1b[0m\n", .{starting_letter});
	print_mutex.unlock();
}

pub fn main() !void {
	// takes ~16 min on 16-thread AMD Zen3+ to search all
	// even through computing with the u576 ints :)
	// since XDYOYOY is pretty early (X isn't far because of threads and D is early), it finds the solution quite quickly
	var pool: std.Thread.Pool = undefined;
	try pool.init(.{.allocator=alloc, .n_jobs=26});
	defer pool.deinit();
	var wg: std.Thread.WaitGroup = .{};
	for ("ABCDEFGHIJKLMNOPQRSTUVWXYZ") |c| {
		pool.spawnWg(&wg, l4_bruteforce, .{c});
	}
	wg.wait();
}
