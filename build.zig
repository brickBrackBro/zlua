const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
    const lua_dep = b.dependency("raw_lua", .{
        .target = target,
        .release = optimize == .ReleaseFast,
    });
    const mod = b.addModule("lua", .{
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.linkLibrary(lua_dep.artifact("lua"));
}
