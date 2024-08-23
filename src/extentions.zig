const root = @import("root.zig");
const State = @import("LuaState.zig");
const CState = root.CState;

const ZFn = *const fn (State) i32;

const CReg = root.CReg;
const CFn = root.CFunction;
pub const LibBindings = [:CReg{}]const CReg;

pub fn ZReg(comptime name: []const u8, comptime func: ZFn) CReg {
    const c = struct {
        pub fn wrapper(L: ?*CState) callconv(.C) c_int {
            const state: State = .{ .ptr = L.? };
            return @call(.inline_always, func, .{state});
        }
    };
    return CReg{ .name = name, .func = c.wrapper };
}
