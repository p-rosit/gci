const std = @import("std");
const internal = @import("../../internal.zig");
const lib = internal.lib;

pub const InterfaceReader = struct {
    reader: lib.GciInterfaceReader,

    pub fn read(reader: InterfaceReader, buffer: []u8) ![]u8 {
        const length = lib.gci_reader_read(reader.reader, buffer.ptr, buffer.len);
        if (length == 0 and buffer.len >= 0) {
            return error.Reader;
        } else {
            return buffer[0..length];
        }
    }
};

pub const Fail = struct {
    inner: lib.GciReaderFail,

    pub fn init(reader: InterfaceReader, reads_before_fail: usize) !Fail {
        var self: Fail = undefined;
        const err = lib.gci_reader_fail_init(
            &self.inner,
            reader.reader,
            reads_before_fail,
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *Fail) InterfaceReader {
        return .{ .reader = lib.gci_reader_fail_interface(&self.inner) };
    }
};

pub fn Reader(AnyReader: type) type {
    // TODO: comptime verify AnyReader is reader
    return extern struct {
        const Self = @This();

        reader: *const AnyReader,

        pub fn init(reader: *const AnyReader) Self {
            return Self{ .reader = reader };
        }

        pub fn interface(self: *Self) InterfaceReader {
            const reader = lib.GciReaderInterface{ .context = self, .read = readCallback };
            return .{ .reader = reader };
        }

        fn readCallback(context: ?*const anyopaque, buffer: [*c]u8, buffer_size: c_int) callconv(.C) c_int {
            std.debug.assert(null != context);
            std.debug.assert(null != buffer);

            const self: *Self = @constCast(@alignCast(@ptrCast(context)));
            const r: *const AnyReader = self.reader;
            const b = @as(*[]u8, @constCast(@ptrCast(&.{ .ptr = buffer, .len = buffer_size }))).*;

            return r.read(b) catch 0;
        }
    };
}

pub const File = struct {
    inner: lib.GciReaderFile,

    pub fn init(file: *lib.FILE) !File {
        var self: File = undefined;
        const err = lib.gci_reader_file_init(&self.inner, file);
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *File) InterfaceReader {
        return .{ .reader = lib.gci_reader_file_interface(&self.inner) };
    }
};

pub const String = struct {
    inner: lib.GciReaderString,

    pub fn init(data: []const u8) !String {
        var self: String = undefined;
        const err = lib.gci_reader_string_init(
            &self.inner,
            data.ptr,
            data.len,
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *String) InterfaceReader {
        return .{ .reader = lib.gci_reader_string_interface(&self.inner) };
    }
};

pub const Buffer = struct {
    inner: lib.GciReaderBuffer,

    pub fn init(reader: InterfaceReader, buffer: []u8) !Buffer {
        var self: Buffer = undefined;
        const err = lib.gci_reader_buffer_init(
            &self.inner,
            reader.reader,
            buffer.ptr,
            buffer.len,
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn double(reader: InterfaceReader, buffer: []u8) !Buffer {
        var self: Buffer = undefined;
        const err = lib.gci_reader_double_buffer_init(
            &self.inner,
            reader.reader,
            buffer.ptr,
            buffer.len,
        );
        try internal.enumToError(err);
        return self;
    }

    pub fn interface(self: *Buffer) InterfaceReader {
        return .{ .reader = lib.gci_reader_buffer_interface(&self.inner) };
    }
};

const testing = std.testing;
const builtin = @import("builtin");
const clib = @cImport({
    @cInclude("stdio.h");
});

test "c tests" {
    _ = @import("test_reader.zig");
}

test "fail init" {
    var c = try String.init("1");

    var context = try Fail.init(c.interface(), 0);
    _ = context.interface();
}

test "fail fails" {
    var c = try String.init("12");

    var context = try Fail.init(c.interface(), 1);
    const reader = context.interface();

    var buffer: [1]u8 = undefined;
    const result = try reader.read(&buffer);
    try testing.expectEqualStrings("1", result);

    const err = reader.read(&buffer);
    try testing.expectError(error.Reader, err);
}

test "file init" {
    var context = try File.init(@ptrFromInt(256));
    _ = context.interface();
}

test "file read" {
    var file: [*c]clib.FILE = undefined;

    switch (builtin.os.tag) {
        .linux => {
            file = clib.tmpfile();
        },
        .windows => {
            @compileError("TODO: allow testing file reader, something to do with `GetTempFileNameA` and `GetTempPathA`");
        },
        else => {
            std.debug.print("TODO: allow testing file reader on this os.\n", .{});
            return;
        },
    }
    defer _ = clib.fclose(file);

    const written = clib.fputs("1", file);
    try testing.expectEqual(written, 1);

    const seek_err = clib.fseek(file, 0, clib.SEEK_SET);
    try testing.expectEqual(0, seek_err);

    var context = try File.init(@ptrCast(file));
    const reader = context.interface();

    var buffer: [1]u8 = undefined;
    const result = try reader.read(&buffer);
    try testing.expectEqualStrings("1", result);

    const err = reader.read(&buffer);
    try testing.expectError(error.Reader, err);
}

test "string init" {
    var data: [1]u8 = undefined;
    var context = try String.init(&data);
    _ = context.interface();
}

test "string read" {
    const data = "zig";
    var context = try String.init(data);
    const reader = context.interface();

    var buffer: [3]u8 = undefined;
    const result = try reader.read(&buffer);
    try testing.expectEqualStrings("zig", result);
}

test "string read overflow" {
    const data = "z";
    var context = try String.init(data);
    const reader = context.interface();

    var buffer: [2]u8 = undefined;
    const result = try reader.read(&buffer);
    try testing.expectEqualStrings("z", result);

    const err = reader.read(&buffer);
    try testing.expectError(error.Reader, err);
}

test "buffer init" {
    const d = "data";
    var c = try String.init(d);

    var buffer: [2]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    _ = context.interface();
}

test "buffer init buffer small" {
    const d = "data";
    var c = try String.init(d);

    var buffer: [1]u8 = undefined;
    const err = Buffer.init(c.interface(), &buffer);
    try testing.expectError(error.Buffer, err);
}

test "buffer read" {
    const d = "data";
    var c = try String.init(d);

    var buffer: [3]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const reader = context.interface();

    var result_buffer: [2]u8 = undefined;
    const result = try reader.read(&result_buffer);
    try testing.expectEqualStrings("da", result);
}

test "buffer read buffer twice" {
    const d = "data";
    var c = try String.init(d);

    var buffer: [3]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const reader = context.interface();

    var result_buffer: [5]u8 = undefined;
    const result = try reader.read(&result_buffer);
    try testing.expectEqualStrings("data", result);
}

test "buffer internal reader empty" {
    const d = "";
    var c = try String.init(d);

    var buffer: [3]u8 = undefined;
    var context = try Buffer.init(c.interface(), &buffer);
    const reader = context.interface();

    var result_buffer: [4]u8 = undefined;
    const err = reader.read(&result_buffer);
    try testing.expectError(error.Reader, err);
}

test "buffer internal reader fail" {
    var c1 = try String.init("1");
    var c2 = try Fail.init(c1.interface(), 0);

    var buffer: [3]u8 = undefined;
    var context = try Buffer.init(c2.interface(), &buffer);
    const reader = context.interface();

    var result_buffer: [2]u8 = undefined;
    const err = reader.read(&result_buffer);
    try testing.expectError(error.Reader, err);
}

test "buffer internal reader large fail" {
    var c1 = try String.init("1");
    var c2 = try Fail.init(c1.interface(), 0);

    var buffer: [3]u8 = undefined;
    var context = try Buffer.init(c2.interface(), &buffer);
    const reader = context.interface();

    var result_buffer: [10]u8 = undefined;
    const err = reader.read(&result_buffer);
    try testing.expectError(error.Reader, err);
}

test "buffer clear error" {
    var c1 = try String.init("122");
    var c2 = try Fail.init(c1.interface(), 1);

    var b: [2]u8 = undefined;
    var context = try Buffer.init(c2.interface(), &b);
    const reader = context.interface();

    var buffer1: [1]u8 = undefined;
    const r1 = try reader.read(&buffer1);
    try testing.expectEqualStrings("1", r1);
    try testing.expectEqual(2, c1.inner.current);

    var buffer2: [2]u8 = undefined;
    const err1 = reader.read(&buffer2);
    try testing.expectError(error.Reader, err1);
    try testing.expectEqual(2, c1.inner.current);

    c2.inner.amount_of_reads = 0; // Clear error

    // Single buffered reader never recovers
    const err2 = reader.read(&buffer2);
    try testing.expectError(error.Reader, err2);
    try testing.expectEqual(2, c1.inner.current);
}

test "buffer clear error large" {
    var c1 = try String.init("1222");
    var c2 = try Fail.init(c1.interface(), 1);

    var b: [2]u8 = undefined;
    var context = try Buffer.init(c2.interface(), &b);
    const reader = context.interface();

    var buffer1: [1]u8 = undefined;
    const r1 = try reader.read(&buffer1);
    try testing.expectEqualStrings("1", r1);
    try testing.expectEqual(2, c1.inner.current);

    var buffer2: [3]u8 = undefined;
    const err1 = reader.read(&buffer2);
    try testing.expectError(error.Reader, err1);
    try testing.expectEqual(2, c1.inner.current);

    c2.inner.amount_of_reads = 0; // Clear error

    // Single buffered reader never recovers
    const err2 = reader.read(&buffer2);
    try testing.expectError(error.Reader, err2);
    try testing.expectEqual(2, c1.inner.current);
}

test "double buffer init" {
    const d = "";
    var c = try String.init(d);

    var buffer: [4]u8 = undefined;
    var context = try Buffer.double(c.interface(), &buffer);
    _ = context.interface();
}

test "double buffer init small" {
    const d = "";
    var c = try String.init(d);

    var buffer: [2]u8 = undefined;
    const err = Buffer.double(c.interface(), &buffer);
    try testing.expectError(error.Buffer, err);
}

test "double buffer init odd" {
    const d = "";
    var c = try String.init(d);

    var buffer: [5]u8 = undefined;
    const err = Buffer.double(c.interface(), &buffer);
    try testing.expectError(error.Buffer, err);
}

test "double buffer clear error" {
    var c1 = try String.init("122");
    var c2 = try Fail.init(c1.interface(), 1);

    var b: [4]u8 = undefined;
    var context = try Buffer.double(c2.interface(), &b);
    const reader = context.interface();

    var buffer1: [1]u8 = undefined;
    const r1 = try reader.read(&buffer1);
    try testing.expectEqualStrings("1", r1);
    try testing.expectEqual(2, c1.inner.current);

    var buffer2: [2]u8 = undefined;
    const err = reader.read(&buffer2);
    try testing.expectError(error.Reader, err);
    try testing.expectEqual(2, c1.inner.current);

    c2.inner.amount_of_reads = 0; // Clear error

    const r2 = try reader.read(&buffer2);
    try testing.expectEqualStrings("22", r2);
    try testing.expectEqual(3, c1.inner.current);
}

test "double buffer clear error large" {
    var c1 = try String.init("1222");
    var c2 = try Fail.init(c1.interface(), 1);

    var b: [4]u8 = undefined;
    var context = try Buffer.double(c2.interface(), &b);
    const reader = context.interface();

    var buffer1: [1]u8 = undefined;
    const r1 = try reader.read(&buffer1);
    try testing.expectEqualStrings("1", r1);
    try testing.expectEqual(2, c1.inner.current);

    var buffer2: [3]u8 = undefined;
    const err = reader.read(&buffer2);
    try testing.expectError(error.Reader, err);
    try testing.expectEqual(2, c1.inner.current);

    c2.inner.amount_of_reads = 0; // Clear error

    const r2 = try reader.read(&buffer2);
    try testing.expectEqualStrings("222", r2);
    try testing.expectEqual(4, c1.inner.current);
}
