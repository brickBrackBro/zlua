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
pub fn TypeId(comptime T: type) ?root.Type {
    return switch (T) {
        bool => .boolean,
        []const u8 => .string,
        root.Number, root.Integer => .number,
        else => null,
    };
}
pub fn toLua(self: anytype, state: State) void {
    const TInfo = @typeInfo(@TypeOf(self));
    switch (TInfo) {
        .Struct => |info| {
            state.creatTable(0, @intCast(info.fields.len));
            inline for (info.fields) |field| {
                toLua(@field(self, field.name), state);
                state.setField(-2, field.name);
                state.pop(1);
            }
        },
        .Optional => |_| {
            toLua(self.?, state);
        },
        .Array => |arr| {
            if (arr.child != u8)
                @compileError("wrong type for field");
            state.push(.string, null, self);
        },
        .Int => {
            state.push(.number, root.Integer, @intCast(self));
        },
        .Float => {
            state.push(.number, root.Number, @floatCast(self));
        },
        .Bool => {
            state.push(.boolean, null, self);
        },
        else => @compileError("wrong type for field"),
    }
}
pub fn FromLua(comptime T: type) fn (State) T {
    return struct {
        pub fn from_lua(state: State) T {
            _ = state;
        }
    }.from_lua;
}
