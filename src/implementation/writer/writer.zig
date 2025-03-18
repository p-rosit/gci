const std = @import("std");
const internal = @import("../../internal.zig");
const lib = internal.lib;

pub const InterfaceWriter = struct {
    writer: lib.GciInterfaceWriter,

    pub fn write(writer: InterfaceWriter, data: []const u8) !void {
        const result = lib.gci_writer_write(writer.writer, data.ptr, data.len);
        if (result != data.len) {
            return error.Writer;
        }
    }
};

inline fn writeData(writer: *const anyopaque, data: []const u8) !void {
    const result = lib.gci_writer_write(writer, data);
    if (result != data.len) {
        return error.Writer;
    }
}

pub fn Writer(AnyWriter: type) type {
    // TODO: comptime verify AnyWriter is writer
    return extern struct {
        const Self = @This();

        writer: *const AnyWriter,

        pub fn init(writer: *const AnyWriter) Self {
            return Self{ .writer = writer };
        }

        pub fn interface(self: *Self) InterfaceWriter {
            const writer = lib.GciInterfaceWriter{ .context = self, .write = writeCallback };
            return .{ .writer = writer };
        }

        fn writeCallback(context: ?*const anyopaque, data: [*c]const u8, data_size: usize) callconv(.C) usize {
            std.debug.assert(null != context);
            std.debug.assert(null != data);

            const self: *Self = @constCast(@alignCast(@ptrCast(context)));
            const w: *const AnyWriter = self.writer;
            const d = @as(*[]u8, @constCast(@ptrCast(&.{ .ptr = data, .len = data_size }))).*;
            return w.write(d) catch 0;
        }
    };
}

pub const File = struct {
    inner: lib.GciWriterFile,

    pub fn init(file: *lib.FILE) !File {
        var self: File = undefined;
        const err = lib.gci_writer_file_init(&self.inner, file);
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *File) InterfaceWriter {
        return .{ .writer = lib.gci_writer_file_interface(&self.inner) };
    }
};

pub const String = struct {
    inner: lib.GciWriterString,

    pub fn init(buffer: []u8) !String {
        if (buffer.len > std.math.maxInt(c_int)) {
            return error.Overflow;
        }

        var self: String = undefined;
        const err = lib.gci_writer_string_init(
            &self.inner,
            buffer.ptr,
            @intCast(buffer.len),
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *String) InterfaceWriter {
        return .{ .writer = lib.gci_writer_string_interface(&self.inner) };
    }
};

pub const Buffer = struct {
    inner: lib.GciWriterBuffer,

    pub fn init(writer: InterfaceWriter, buffer: []u8) !Buffer {
        if (buffer.len >= std.math.maxInt(c_int)) {
            return error.Overflow;
        }

        var self: Buffer = undefined;
        const err = lib.gci_writer_buffer_init(
            &self.inner,
            writer.writer,
            buffer.ptr,
            @intCast(buffer.len),
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *Buffer) InterfaceWriter {
        return .{ .writer = lib.gci_writer_buffer_interface(&self.inner) };
    }

    pub fn flush(self: *Buffer) !void {
        const result = lib.gci_writer_buffer_flush(&self.inner);
        if (!result) {
            return error.Writer;
        }
    }
};

const testing = std.testing;
const builtin = @import("builtin");
const clib = @cImport({
    @cInclude("stdio.h");
});

test "c tests" {
    _ = @import("test_writer.zig");
}

test "zig writer" {
    const Fifo = std.fifo.LinearFifo(u8, .Slice);
    const FifoWriter = Writer(Fifo.Writer);

    var buffer: [1]u8 = undefined;
    var fifo = Fifo.init(&buffer);

    var context = FifoWriter.init(&fifo.writer());
    const writer = context.interface();

    try writer.write("1");
    try testing.expectEqualStrings("1", &buffer);
}

test "file init" {
    var context = try File.init(@ptrFromInt(256));
    _ = context.interface();
}

test "file write" {
    var file: [*c]clib.FILE = undefined;

    switch (builtin.os.tag) {
        .linux => {
            file = clib.tmpfile();
        },
        .windows => {
            @compileError("TODO: allow testing file writer, something to do with `GetTempFileNameA` and `GetTempPathA`");
        },
        else => {
            std.debug.print("TODO: allow testing file writer on this os.\n", .{});
            return;
        },
    }
    defer _ = clib.fclose(file);

    var context = try File.init(@as([*c]lib.FILE, @ptrCast(file)));
    const writer = context.interface();

    try writer.write("1");

    const seek_err = clib.fseek(file, 0, lib.SEEK_SET);
    try testing.expectEqual(seek_err, 0);

    var buffer: [2]u8 = undefined;
    const result = clib.fread(&buffer, 1, 2, file);
    try testing.expectEqual(1, result);

    try testing.expectEqualStrings("1", buffer[0..1]);
}

test "string init" {
    var buffer: [0]u8 = undefined;
    var context = try String.init(&buffer);
    _ = context.interface();
}

test "string init overflow" {
    var fake_large_buffer = try testing.allocator.alloc(u8, 2);
    fake_large_buffer.len = @as(usize, std.math.maxInt(c_int)) + 1;
    defer {
        fake_large_buffer.len = 2;
        testing.allocator.free(fake_large_buffer);
    }

    const err = String.init(@ptrCast(fake_large_buffer));
    try testing.expectError(error.Overflow, err);
}

test "string write" {
    var buffer: [2]u8 = undefined;
    var context = try String.init(&buffer);
    const writer = context.interface();

    try writer.write("12");
    try testing.expectEqualStrings("12", &buffer);
}

test "string overflow" {
    var buffer: [0]u8 = undefined;
    var context = try String.init(&buffer);
    const writer = context.interface();

    const err = writer.write("1");
    try testing.expectError(error.Writer, err);
}

test "buffer init" {
    var b: [3]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [1]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    _ = context.interface();
}

test "buffer init buffer small" {
    var b: [3]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [0]u8 = undefined;
    const err = Buffer.init(c.interface(), &buffer);
    try testing.expectError(error.Buffer, err);
}

test "buffer init overflow" {
    var fake_large_buffer = try testing.allocator.alloc(u8, 2);
    fake_large_buffer.len = @as(usize, std.math.maxInt(c_int)) + 1;
    defer {
        fake_large_buffer.len = 2;
        testing.allocator.free(fake_large_buffer);
    }

    var b: [3]u8 = undefined;
    var c = try String.init(&b);

    const err = Buffer.init(c.interface(), @ptrCast(fake_large_buffer));
    try testing.expectError(error.Overflow, err);
}

test "buffer write" {
    var b: [1]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [1]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const writer = context.interface();

    try writer.write("1");
    try testing.expectEqualStrings("1", &b);
}

test "buffer flush" {
    var b: [1]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [2]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const writer = context.interface();

    try writer.write("1");

    try context.flush();
    try testing.expectEqualStrings("1", &b);
}

test "buffer internal writer fail" {
    var b: [0]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [1]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const writer = context.interface();

    const err = writer.write("1");
    try testing.expectError(error.Writer, err);
}

test "buffer flush writer fail" {
    var b: [0]u8 = undefined;
    var c = try String.init(&b);

    var buffer: [2]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const writer = context.interface();

    try writer.write("1");

    const err = context.flush();
    try testing.expectError(error.Writer, err);
}
