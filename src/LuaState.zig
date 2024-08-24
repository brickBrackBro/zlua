const std = @import("std");
const mem = std.mem;
const lua = @import("root.zig");
const c = lua.c;
pub const Error = lua.Error;
const Status = lua.Status;
const Type = lua.Type;
const CFunction = lua.CFunction;
const Integer = lua.Integer;
const Number = lua.Number;
const String = []const u8;
const CString = []const u8;
const CReg = lua.CReg;
const Self = @This();
ptr: *c.lua_State,
pub fn init() Error!Self {
    const ptr = c.luaL_newstate() orelse return error.OutOfMemory;
    return .{
        .ptr = ptr,
    };
}

pub inline fn deinit(self: Self) void {
    c.lua_close(self.ptr);
}
pub fn err(self: Self, comptime fmt: []const u8, args: anytype) noreturn {
    var buff = [_]u8{0} ** 2048;
    const message = std.fmt.bufPrintZ(&buff, fmt, args) catch @panic("OOM");
    _ = c.luaL_error(self.ptr, message.ptr);
    unreachable;
}
/// Opens all standard Lua libraries into the given state
pub inline fn openLibs(self: Self) void {
    c.luaL_openlibs(self.ptr);
}

pub fn creatTable(self: Self, narr: c_int, nrec: c_int) void {
    c.lua_createtable(self.ptr, narr, nrec);
}
pub inline fn newUserData(self: Self, comptime T: type, n_uvalue: ?c_int) *T {
    return @ptrCast(@alignCast(c.lua_newuserdatauv(self.ptr, @sizeOf(T), n_uvalue orelse 0)));
}
pub const NextResult = enum(c_int) {
    done = 0,
    value = 1,
};
pub inline fn next(self: Self, index: c_int) NextResult {
    return @enumFromInt(c.lua_next(self.ptr, index));
}
pub fn pcall(self: Self, nargs: i32, nresults: i32, msgh: ?i32) Error!void {
    const status: Status = @enumFromInt(c.lua_pcallk(self.ptr, nargs, nresults, msgh orelse 0, 0, null));
    try status.check();
}

pub fn loadBuffer(self: Self, buff: []const u8, name: [:0]const u8) Error!void {
    const status: Status = @enumFromInt(c.luaL_loadbufferx(self.ptr, buff.ptr, buff.len, name.ptr, null));
    try status.check();
}

pub fn loadFile(self: Self, file_name: [:0]const u8) Error!void {
    const status: Status = @enumFromInt(c.luaL_loadfilex(self.ptr, file_name.ptr, null));
    try status.check();
}

pub fn loadString(self: Self, str: [:0]const u8) Error!void {
    const status: Status = @enumFromInt(c.luaL_loadstring(self.ptr, str.ptr));
    try status.check();
}
pub inline fn pop(self: Self, n: i32) void {
    c.lua_pop(self.ptr, n);
}
pub fn PushType(comptime lua_type: Type, comptime T: ?type) type {
    return switch (lua_type) {
        .number => switch (T.?) {
            Integer, Number => T.?,
            else => @compileError("unsupponted number type: " ++ @typeName(T.?)),
        },
        .string => []const u8,
        .boolean => bool,
        .light_user_data => ?*anyopaque,
        .function => CFunction,
        else => @compileError("unsupponted type " ++ @tagName(lua_type)),
    };
}
pub fn pushOptional(self: Self, comptime lua_type: Type, comptime T: ?type, val: ?PushType(lua_type, T)) void {
    if (val) |v| {
        self.push(lua_type, T, v);
    } else {
        self.pushNil();
    }
}
pub fn push(self: Self, comptime lua_type: Type, comptime T: ?type, val: PushType(lua_type, T)) void {
    switch (lua_type) {
        .function => self.pushCFunction(val),
        .light_user_data => self.pushLightUserData(val),
        .boolean => self.pushBoolean(val),
        .string => self.pushString(val),
        .number => switch (T.?) {
            Integer => self.pushInteger(val),
            Number => self.pushNumber(val),
            else => @compileError("unsupponted number type: " ++ @typeName(T.?)),
        },
        else => @compileError("unsupponted type " ++ @tagName(lua_type)),
    }
}
pub inline fn pushBoolean(self: Self, b: bool) void {
    c.lua_pushboolean(self.ptr, @intCast(@intFromBool(b)));
}
pub inline fn pushCClosure(self: Self, f: CFunction, n: c_int) void {
    c.lua_pushcclosure(self.ptr, f, n);
}
pub inline fn pushGlobalTable(self: Self) void {
    c.lua_pushglobaltable(self.ptr);
}
pub inline fn pushInteger(self: Self, n: Integer) void {
    c.lua_pushinteger(self.ptr, n);
}
pub inline fn pushLightUserData(self: Self, p: ?*anyopaque) void {
    c.lua_pushlightuserdata(self.ptr, p);
}
pub fn pushString(self: Self, s: []const u8) []const u8 {
    const p = c.lua_pushlstring(self.ptr, s.ptr, s.len);
    return p[0..s.len];
}
pub inline fn pushNil(self: Self) void {
    c.lua_pushnil(self.ptr);
}
pub inline fn pushNumber(self: Self, n: Number) void {
    c.lua_pushnumber(self.ptr, n);
}
pub inline fn pushThread(self: Self) bool {
    c.lua_pushthread(self.ptr) == 1;
}
pub inline fn pushCFunction(self: Self, f: CFunction) void {
    c.lua_pushcclosure(self.ptr, f, 0);
}
pub inline fn pushValue(self: Self, index: c_int) void {
    c.lua_pushvalue(self.ptr, index);
}
pub fn PopType(comptime lua_type: Type, comptime T: ?type) type {
    return switch (lua_type) {
        .light_user_data, .user_data => *T.?,
        .string => ?String,
        .boolean => bool,
        .number => switch (T.?) {
            Integer, Number => T.?,
            else => @compileError(std.fmt.comptimePrint("Invalid lua type: {s}", .{@tagName(lua_type)})),
        },
        else => @compileError(std.fmt.comptimePrint("Invalid lua type: {s}", .{@tagName(lua_type)})),
    };
}
pub fn toOptionalValue(self: Self, comptime lua_type: Type, comptime T: ?type, index: c_int) ?PopType(lua_type, T) {
    if (self.getType(index) == .nil)
        return null;
    return self.toValue(lua_type, T, index);
}
pub fn toValue(self: Self, comptime lua_type: Type, comptime T: ?type, index: c_int) PopType(lua_type, T) {
    return switch (lua_type) {
        .light_user_data, .user_data => self.toUserData(T.?, index),
        .number => switch (T.?) {
            Integer => self.toInteger(index),
            Number => self.toNumber(index),
            else => @compileError("invalid number type: " ++ @typeName(T.?)),
        },
        .string => self.toString(index),
        .boolean => self.toBoolean(index),
        else => @compileError("Invalid lua type: " ++ @tagName(lua_type)),
    };
}
pub inline fn toBoolean(self: Self, index: c_int) bool {
    c.lua_toboolean(self.ptr, index) == 1;
}
pub inline fn toUserData(self: Self, comptime T: type, index: c_int) *T {
    return @ptrCast(@alignCast(c.lua_touserdata(self.ptr, index)));
}
pub inline fn toInteger(self: Self, index: c_int) Integer {
    return c.lua_tointegerx(self.ptr, index, null);
}
pub inline fn toString(self: Self, index: c_int) ?String {
    var len: usize = 0;
    const res: ?[*]const u8 = c.lua_tolstring(self.ptr, index, &len);
    return (res orelse return null)[0..len];
}
pub inline fn toNumber(self: Self, idx: c_int) Number {
    return c.lua_tonumberx(self.ptr, idx, null);
}
/// returns true if userdata has value.
pub inline fn setIUserValue(self: Self, index: c_int, n: c_int) bool {
    return c.lua_setiuservalue(self.ptr, index, n) == 1;
}
pub inline fn setField(self: Self, index: c_int, k: [:0]const u8) void {
    c.lua_setfield(self.ptr, index, k.ptr);
}
pub inline fn setGlobal(self: Self, name: [:0]const u8) void {
    c.lua_setglobal(self.ptr, name.ptr);
}
pub inline fn setI(self: Self, index: c_int, n: Integer) void {
    c.lua_seti(self.ptr, index, n);
}
pub inline fn setMetatable(self: Self, index: c_int) void {
    _ = c.lua_setmetatable(self.ptr, index);
}
pub inline fn setNamedMetatable(self: Self, tname: [:0]const u8) void {
    c.luaL_setmetatable(self.ptr, tname.ptr);
}
pub const NewMetatableResult = enum(c_int) {
    key_exists = 0,
    new_key = 1,
};
pub fn newMetatable(self: Self, tname: [:0]const u8) NewMetatableResult {
    const res = c.luaL_newmetatable(self.ptr, tname.ptr);
    return @enumFromInt(res);
}

pub inline fn setTable(self: Self, index: c_int) void {
    c.lua_settable(self.ptr, index);
}
pub inline fn setFuncs(self: Self, l: [:CReg{}]const CReg, nup: c_int) void {
    c.luaL_setfuncs(self.ptr, l.ptr, nup);
}
pub inline fn newLib(self: Self, l: [:CReg{}]const CReg) void {
    c.lua_createtable(self.ptr, 0, @intCast(l.len));
    c.luaL_setfuncs(self.ptr, l.ptr, 0);
}
pub fn upvalueIndex(_: Self, i: c_int) c_int {
    return c.lua_upvalueindex(i);
}
pub fn getField(self: Self, index: c_int, k: [:0]const u8) Type {
    const ret = c.lua_getfield(self.ptr, index, k.ptr);
    return @enumFromInt(ret);
}
pub fn addRequireLib(self: Self, mod_name: [:0]const u8, callback: CFunction) void {
    _ = c.luaL_getsubtable(self.ptr, c.LUA_REGISTRYINDEX, c.LUA_PRELOAD_TABLE);
    self.pushCFunction(callback);
    self.setField(-2, mod_name);
    self.pop(1);
}
pub fn getGlobal(self: Self, name: [:0]const u8) Type {
    const ret = c.lua_getglobal(self.ptr, name.ptr);
    return @enumFromInt(ret);
}
pub fn getI(self: Self, index: c_int, i: c.lua_Integer) Type {
    const ret = c.lua_geti(self.ptr, index, i);
    return @enumFromInt(ret);
}
/// returns true if object at `n` has a metatable
pub fn getMetatable(self: Self, n: c_int) bool {
    return c.lua_getmetatable(self.ptr, n) == 1;
}
pub fn getNamedMetatable(self: Self, name: [:0]const u8) void {
    _ = c.lua_getfield(self.ptr, c.LUA_REGISTRYINDEX, name.ptr);
}
pub fn getTable(self: Self, index: c_int) Type {
    const ret = c.lua_gettable(self.ptr, index);
    return @enumFromInt(ret);
}
pub inline fn getTop(self: Self) c_int {
    return c.lua_gettop(self.ptr);
}
pub fn getIUserValue(self: Self, index: c_int, n: c_int) Type {
    const ret = c.lua_getiuservalue(self.ptr, index, n);
    return @enumFromInt(ret);
}
pub inline fn insert(self: Self, index: c_int) void {
    c.lua_insert(self.ptr, index);
}
pub inline fn remove(self: Self, index: c_int) void {
    c.lua_remove(self.ptr, index);
}
pub inline fn replace(self: Self, index: c_int) void {
    c.lua_replace(self.ptr, index);
}
pub inline fn rotate(self: Self, idx: c_int, n: c_int) void {
    c.lua_rotate(self.ptr, idx, n);
}
pub fn getType(self: Self, index: c_int) Type {
    const res = c.lua_type(self.ptr, index);
    return @enumFromInt(res);
}
pub fn typeName(self: Self, tp: c_int) []const u8 {
    const ptr: [*:0]const u8 = c.lua_typename(self.ptr, tp);
    return ptr[0..mem.indexOfSentinel(u8, 0, ptr)];
}
pub inline fn isBoolean(self: Self, index: c_int) bool {
    return self.getType(index) == .boolean;
}
pub inline fn isCFunction(self: Self, index: c_int) bool {
    return c.lua_iscfunction(self.ptr, index) == 1;
}
pub inline fn isFunction(self: Self, index: c_int) bool {
    return self.getType(index) == .function;
}
pub inline fn isInteger(self: Self, index: c_int) bool {
    return c.lua_isinteger(self.ptr, index) == 1;
}
pub inline fn isLightUserData(self: Self, index: c_int) bool {
    return self.getType(index) == .light_user_data;
}
pub inline fn isNil(self: Self, index: c_int) bool {
    return self.getType(index) == .nil;
}
pub inline fn isNone(self: Self, index: c_int) bool {
    return self.getType(index) == .none;
}
pub inline fn isNoneOrNil(self: Self, index: c_int) bool {
    return switch (self.getType(index)) {
        .none, .nil => true,
        else => false,
    };
}
pub inline fn isNumber(self: Self, index: c_int) bool {
    return self.getType(index) == .number;
}
pub inline fn isString(self: Self, index: c_int) bool {
    return self.getType(index) == .string;
}
pub inline fn isTable(self: Self, index: c_int) bool {
    return self.getType(index) == .table;
}
pub inline fn isThread(self: Self, index: c_int) bool {
    return self.getType(index) == .thread;
}
pub inline fn isUserData(self: Self, index: c_int) bool {
    return self.getType(index) == .user_data;
}
pub inline fn checkType(self: Self, arg: c_int, t: Type) void {
    c.luaL_checktype(self.ptr, arg, @intFromEnum(t));
}
pub inline fn checkAny(self: Self, arg: c_int) void {
    c.luaL_checkany(self.ptr, arg);
}
pub inline fn checkInteger(self: Self, arg: c_int) Integer {
    return c.luaL_checkinteger(self.ptr, arg);
}
pub inline fn checkString(self: Self, arg: c_int) [:0]const u8 {
    const ptr: [*:0]const u8 = c.luaL_checklstring(self.ptr, arg, null);
    return ptr[0..mem.indexOfSentinel(u8, 0, ptr) :0];
}
pub inline fn checkNumber(self: Self, arg: c_int) Number {
    return c.luaL_checknumber(self.ptr, arg);
}
pub inline fn checkUData(self: Self, comptime T: type, arg: c_int, tname: [:0]const u8) *T {
    return @ptrCast(@alignCast(c.luaL_checkudata(self.ptr, arg, tname)));
}
