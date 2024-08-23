const std = @import("std");
const root = @import("root.zig");
const State = @import("LuaState.zig");
const CState = root.CState;

const ZFn = *const fn (State) i32;

const CReg = root.CReg;
const CFn = root.CFunction;
pub const LibBindings = [:CReg{}]const CReg;

pub fn ZReg(comptime name: [:0]const u8, comptime func: ZFn) CReg {
    return CReg{ .name = name.ptr, .func = LuaBind(func) };
}

pub fn LuaBind(comptime func: ZFn) CFn {
    return struct {
        pub fn genbinding(L: ?*CState) callconv(.C) c_int {
            const state: State = .{ .ptr = L.? };
            return @call(.always_inline, func, .{state});
        }
    }.genbinding;
}
