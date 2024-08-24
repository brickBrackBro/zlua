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
            }
        },
        .Optional => |_| {
            if (self) |v|
                toLua(v, state)
            else
                state.pushNil();
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
pub fn fromLua(comptime T: type, state: State) T {
    var val: T = undefined;
    const lua_type: root.Type = switch (T) {
        ?[]const u8, []const u8 => .string,
        bool => .boolean,
        root.Integer, root.Number => .number,
        else => undefined,
    };
    switch (T) {
        ?bool, ?root.Integer, ?root.Number => {
            val = state.toOptionalValue(lua_type, @typeInfo(T).Optional.child, -1);
        },
        bool, root.Integer, root.Number => {
            val = state.toValue(lua_type, T, -1);
        },
        ?[]const u8 => {
            val = state.toOptionalValue(.string, null, -1);
        },
        []const u8 => {
            val = state.toValue(.string, null, -1) orelse "";
        },
        else => {
            const TInfo = @typeInfo(T);
            switch (TInfo) {
                .Struct => |info| {
                    inline for (info.fields) |field| {
                        state.getField(-1, field.name);
                        @field(val, field.name) = fromLua(field.type, state);
                        state.pop(1);
                    }
                },
                else => @compileError("invalid type for fromLua " ++ @typeName(T)),
            }
        },
    }
    return val;
}
