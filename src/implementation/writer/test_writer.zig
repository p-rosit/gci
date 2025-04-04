const std = @import("std");
const builtin = @import("builtin");
const testing = @import("std").testing;
const lib = @import("../../internal.zig").lib;
const clib = @cImport({
    @cInclude("stdio.h");
});

test "file init" {
    var context: lib.GciWriterFile = undefined;
    const init_err = lib.gci_writer_file_init(&context, @ptrFromInt(256));
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    _ = lib.gci_writer_file_interface(&context);
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

    var context: lib.GciWriterFile = undefined;
    const init_err = lib.gci_writer_file_init(&context, @as([*c]lib.FILE, @ptrCast(file)));
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_file_interface(&context);

    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, res);

    const seek_err = clib.fseek(file, 0, lib.SEEK_SET);
    try testing.expectEqual(seek_err, 0);

    var buffer: [2]u8 = undefined;
    const result = clib.fread(&buffer, 1, 2, file);
    try testing.expectEqual(1, result);

    try testing.expectEqualStrings("1", buffer[0..1]);
}

test "string init" {
    var buffer: [1]u8 = undefined;
    var context: lib.GciWriterString = undefined;
    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    _ = lib.gci_writer_string_interface(&context);
}

test "string init null" {
    var buffer: [1]u8 = undefined;
    const init_err = lib.gci_writer_string_init(null, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "string buffer null" {
    var context: lib.GciWriterString = undefined;
    const init_err = lib.gci_writer_string_init(&context, null, 2);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "string write" {
    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterString = undefined;

    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_string_interface(&context);

    const res = lib.gci_writer_write(writer, "12", 2);
    try testing.expectEqual(2, res);
    try testing.expectEqualStrings("12", &buffer);
}

test "string write multiple" {
    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterString = undefined;

    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_string_interface(&context);

    const write_err1 = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, write_err1);

    const write_err2 = lib.gci_writer_write(writer, "2", 1);
    try testing.expectEqual(1, write_err2);

    try testing.expectEqualStrings("12", &buffer);
}

test "string overflow" {
    var buffer: [0]u8 = undefined;
    var context: lib.GciWriterString = undefined;

    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_string_interface(&context);

    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(0, res);
}

test "string start" {
    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterString = undefined;

    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_string_interface(&context);

    const s1 = lib.gci_writer_string_start(&context);
    try testing.expectEqual(0, s1);

    const res = lib.gci_writer_write(writer, "12", 2);
    try testing.expectEqual(2, res);
    try testing.expectEqualStrings("12", &buffer);

    const s2 = lib.gci_writer_string_start(&context);
    try testing.expectEqual(2, s2);
}

test "string end" {
    var buffer: [5]u8 = undefined;
    var context: lib.GciWriterString = undefined;

    const init_err = lib.gci_writer_string_init(&context, &buffer, buffer.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_string_interface(&context);

    const res = lib.gci_writer_write(writer, "12345", 5);
    try testing.expectEqual(5, res);

    var r1: []u8 = undefined;
    const err1 = lib.gci_writer_string_end(&context, 0, @ptrCast(&r1.ptr), &r1.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), err1);
    try testing.expectEqualStrings("12345", r1);

    var r2: []u8 = undefined;
    const err2 = lib.gci_writer_string_end(&context, 5, @ptrCast(&r2.ptr), &r2.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), err2);
    try testing.expectEqualStrings("", r2);

    var r3: []u8 = undefined;
    const err3 = lib.gci_writer_string_end(&context, 3, @ptrCast(&r3.ptr), &r3.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), err3);
    try testing.expectEqualStrings("45", r3);
}

test "buffer init" {
    var c: lib.GciWriterString = undefined;

    var buffer: [1]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    _ = lib.gci_writer_buffer_interface(&context);
}

test "buffer init null" {
    var c: lib.GciWriterString = undefined;
    var buffer: [1]u8 = undefined;
    const init_err = lib.gci_writer_buffer_init(
        null,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "buffer init buffer null" {
    var c: lib.GciWriterString = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        null,
        2,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "buffer init buffer small" {
    var c: lib.GciWriterString = undefined;
    var buffer: [0]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_BUFFER), init_err);
}

test "buffer write" {
    var b: [1]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [1]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);

    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, res);
    try testing.expectEqualStrings("1", &b);
}

test "buffer write moderate" {
    var b: [2]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);

    const res1 = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, res1);

    // First buffer is filled and flushed, then buffer filled with rest of string
    const res2 = lib.gci_writer_write(writer, "12", 1);
    try testing.expectEqual(1, res2);

    // Buffer is not flushed after second write
    try testing.expectEqualStrings("11", &b);
}

test "buffer write large" {
    var b: [7]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);

    // First buffer is filled and flushed, then rest of string is written
    // directly without passing buffer
    const res = lib.gci_writer_write(writer, "1234567", 7);
    try testing.expectEqual(7, res);

    // Rest of string didn't pass buffer since last 7 was written instead
    // of left in buffer
    try testing.expectEqualStrings("1234567", &b);
}

test "buffer flush" {
    var b: [1]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);

    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, res);

    const flush_res = lib.gci_writer_buffer_flush(&context);
    try testing.expect(flush_res);
    try testing.expectEqualStrings("1", &b);
}

test "buffer internal writer fail" {
    var b: [0]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [1]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);
    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(0, res);
}

test "buffer flush writer fail" {
    var b: [0]u8 = undefined;
    var c: lib.GciWriterString = undefined;
    const i_err = lib.gci_writer_string_init(&c, &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciWriterBuffer = undefined;
    const init_err = lib.gci_writer_buffer_init(
        &context,
        lib.gci_writer_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const writer = lib.gci_writer_buffer_interface(&context);

    const res = lib.gci_writer_write(writer, "1", 1);
    try testing.expectEqual(1, res);

    const flush_res = lib.gci_writer_buffer_flush(&context);
    try testing.expect(!flush_res);
}
