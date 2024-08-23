pub const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});
pub const extentions = @import("extentions.zig");
pub const regestry_index = c.LUA_REGISTRYINDEX;
pub const Error = error{
    RuntimeError,
    OutOfMemory,
    MessageHandlerError,
    SyntaxError,
    FileError,
};
pub const Status = enum(c_int) {
    ok = c.LUA_OK,
    err_run = c.LUA_ERRRUN,
    err_mem = c.LUA_ERRMEM,
    err_err = c.LUA_ERRERR,
    err_syntax = c.LUA_ERRSYNTAX,
    yield = c.LUA_YIELD,
    err_file = c.LUA_ERRFILE,
    pub fn check(self: Status) Error!void {
        return switch (self) {
            .err_run => error.RuntimeError,
            .err_mem => error.OutOfMemory,
            .err_err => error.MessageHandlerError,
            .err_syntax => error.SyntaxError,
            .err_file => error.FileError,
            else => {},
        };
    }
};
pub const Type = enum(c_int) {
    nil = c.LUA_TNIL,
    none = c.LUA_TNONE,
    number = c.LUA_TNUMBER,
    boolean = c.LUA_TBOOLEAN,
    string = c.LUA_TSTRING,
    table = c.LUA_TTABLE,
    function = c.LUA_TFUNCTION,
    user_data = c.LUA_TUSERDATA,
    thread = c.LUA_TTHREAD,
    light_user_data = c.LUA_TLIGHTUSERDATA,
};
pub const LuaAlloc = c.lua_Alloc;
pub const CFunction = c.lua_CFunction;
pub const Debug = c.lua_Debug;
pub const Hook = c.lua_Hook;
pub const Integer = c.lua_Integer;
pub const KContext = c.lua_KContext;
pub const KFunction = c.lua_KFunction;
pub const Number = c.lua_Number;
pub const CReader = c.lua_Reader;
pub const Unsigned = c.lua_Unsigned;
pub const WarnFunction = c.lua_WarnFunction;
pub const CWriter = c.lua_Writer;
pub const CBuffer = c.luaL_Buffer;
pub const CReg = c.luaL_Reg;
pub const CStream = c.luaL_Stream;
pub const CState = c.lua_State;
pub const State = @import("LuaState.zig");
