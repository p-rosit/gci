const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "gci",
        .root_source_file = b.path("src/gci.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(b.path("src/interface"));
    lib.addIncludePath(b.path("src/implementation/reader"));
    b.installArtifact(lib);

    lib.addCSourceFiles(.{
        .root = b.path("src/implementation/reader"),
        .files = &.{"reader.c"},
    });
    lib.installHeader(b.path("src/interface/gci_interface_reader.h"), "gci_interface_reader.h");
    lib.installHeader(b.path("src/gci_common.h"), "gci_common.h");

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/gci.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.addIncludePath(b.path("src"));
    lib_unit_tests.addIncludePath(b.path("src/interface"));
    lib_unit_tests.addIncludePath(b.path("src/implementation/reader"));
    lib_unit_tests.linkLibrary(lib);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
