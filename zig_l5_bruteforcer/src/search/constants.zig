const data = @import("../util/data.zig");

pub const DATA = data.level5.data;
pub const DATA_LEN = 392;
pub const K0 = data.level5.hint[0..17];
pub const K0_LEN = 17;
pub const K0E = @import("../util/crypt.zig").extract_key(K0_LEN, K0.*);
pub const N0 = 7;
pub const N1 = 27;
