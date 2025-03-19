const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("gci", .{
        .root_source_file = b.path("src/gci.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("src"));
    mod.addIncludePath(b.path("src/interface"));
    mod.addIncludePath(b.path("src/implementation"));

    const lib = b.addStaticLibrary(.{
        .name = "gci",
        .root_source_file = b.path("src/gci.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.linkLibrary(lib);
    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(b.path("src/interface"));
    lib.addIncludePath(b.path("src/implementation"));
    b.installArtifact(lib);

    lib.addCSourceFiles(.{
        .root = b.path("src/implementation"),
        .files = &.{ "reader/reader.c", "writer/writer.c" },
    });
    lib.installHeader(b.path("src/interface/gci_interface_reader.h"), "gci_interface_reader.h");
    lib.installHeader(b.path("src/implementation/gci_reader.h"), "gci_reader.h");
    lib.installHeader(b.path("src/interface/gci_interface_writer.h"), "gci_interface_writer.h");
    lib.installHeader(b.path("src/implementation/gci_writer.h"), "gci_writer.h");
    lib.installHeader(b.path("src/gci_common.h"), "gci_common.h");

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/gci.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.addIncludePath(b.path("src"));
    lib_unit_tests.addIncludePath(b.path("src/interface"));
    lib_unit_tests.addIncludePath(b.path("src/implementation"));
    lib_unit_tests.linkLibrary(lib);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
