// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "core",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // TODO: have file that simply saves the paths to c packages. if path nonexistent or path bad, try to use env vars
    // if can't find, tell user and exit build.

    // exe.addIncludePath(std.Build.LazyPath{.path="D:/programs/zig-windows-x86_64-0.11.0-dev.3105+e46d7a369.lib/libc/include/any-windows-any"});
    // exe.addIncludePath(std.Build.LazyPath{.path="D:/libs/VulkanMemoryAllocator-3.0.1/include"});
    // exe.addIncludePath(std.Build.LazyPath{.path="D:/libs/VulkanSDK/1.3.243.0/Include"});
    // exe.addIncludePath(std.Build.LazyPath{.path="D:/libs/glfw-3.3.8.bin.WIN64/include"});
    // exe.addIncludePath(std.Build.LazyPath{.path="include"});

    // exe.linkLibC();

    // exe.addLibraryPath(std.Build.LazyPath{.path="D:/libs/glfw-3.3.8.bin.WIN64/lib-mingw-w64"});
    // exe.linkSystemLibraryName("glfw3");

    // exe.addLibraryPath(std.Build.LazyPath{.path="D:/libs/VulkanSDK/1.3.243.0/Lib"});
    // exe.linkSystemLibrary("vulkan-1");

    // exe.addLibraryPath(std.Build.LazyPath{.path="C:/Windows/System32"});
    // exe.linkSystemLibrary("gdi32");

    // const image_module = b.createModule(.{
    //     .source_file = .{ .path="src/image/image.zig" },
    //     .dependencies = &.{}
    // });
    // exe.addModule("image", image_module);

    // const string_module = b.createModule(.{
    //     .source_file = .{ .path="src/utils/string.zig" },
    //     .dependencies = &.{}
    // });
    // exe.addModule("string", string_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

const std = @import("std");