const std = @import("std");
const builtin = @import("builtin");
const testing = @import("std").testing;
const lib = @import("../../internal.zig").lib;
const clib = @cImport({
    @cInclude("stdio.h");
});

test "fail init" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var context: lib.GciReaderFail = undefined;
    const init_err = lib.gci_reader_fail_init(&context, lib.gci_reader_string_interface(&c), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    _ = lib.gci_reader_fail_interface(&context);
}

test "fail fails" {
    const data = "12";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var context: lib.GciReaderFail = undefined;
    const init_err = lib.gci_reader_fail_init(&context, lib.gci_reader_string_interface(&c), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const reader = lib.gci_reader_fail_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", buffer[0..1]);
    try testing.expect(!lib.gci_reader_eof(reader));

    const length2 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(0, length2);
    try testing.expect(!lib.gci_reader_eof(reader));

    context.reads_before_fail = 2;
    const length3 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length3);
    try testing.expectEqualStrings("2", buffer[0..1]);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "file init" {
    var context: lib.GciReaderFile = undefined;
    const init_err = lib.gci_reader_file_init(&context, @ptrFromInt(256));
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
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

    var context: lib.GciReaderFile = undefined;
    const init_err = lib.gci_reader_file_init(&context, @ptrCast(file));
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_file_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer);
    try testing.expect(!lib.gci_reader_eof(reader));

    const length2 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(0, length2);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "string init" {
    var data: [1]u8 = undefined;
    var context: lib.GciReaderString = undefined;
    const init_err = lib.gci_reader_string_init(&context, &data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    _ = lib.gci_reader_string_interface(&context);
}

test "string init null" {
    var data: [1]u8 = undefined;
    const init_err = lib.gci_reader_string_init(null, &data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "string init null buffer" {
    var context: lib.GciReaderString = undefined;
    const init_err = lib.gci_reader_string_init(&context, null, 2);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "string read" {
    const data = "zig";
    var context: lib.GciReaderString = undefined;
    const init_err = lib.gci_reader_string_init(&context, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_string_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer: [3]u8 = undefined;
    const length = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(3, length);
    try testing.expectEqualStrings("zig", &buffer);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "string read separate" {
    const data = "12";
    var context: lib.GciReaderString = undefined;
    const init_err = lib.gci_reader_string_init(&context, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_string_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer);
    try testing.expect(!lib.gci_reader_eof(reader));

    const length2 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length2);
    try testing.expectEqualStrings("2", &buffer);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "string read overflow" {
    const data = "z";
    var context: lib.GciReaderString = undefined;
    const init_err = lib.gci_reader_string_init(&context, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_string_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer: [2]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("z", buffer[0..1]);
    try testing.expect(lib.gci_reader_eof(reader));

    const length2 = lib.gci_reader_read(reader, &buffer, buffer.len);
    try testing.expectEqual(0, length2);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "buffer init" {
    const data = "data";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    _ = lib.gci_reader_buffer_interface(&context);
}

test "buffer init null" {
    const data = "data";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    const init_err = lib.gci_reader_buffer_init(
        null,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "buffer init null buffer" {
    const data = "data";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        null,
        1,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "buffer read" {
    const data = "data";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [3]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var result_buffer: [2]u8 = undefined;
    const length = lib.gci_reader_read(reader, &result_buffer, result_buffer.len);
    try testing.expectEqual(2, length);
    try testing.expectEqualStrings("da", result_buffer[0..2]);
    try testing.expect(!lib.gci_reader_eof(reader));
}

test "buffer read buffer twice" {
    const data = "data";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [3]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var result_buffer: [5]u8 = undefined;
    const length = lib.gci_reader_read(reader, &result_buffer, result_buffer.len);
    try testing.expectEqual(4, length);
    try testing.expectEqualStrings("data", result_buffer[0..4]);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "buffer internal reader empty" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [3]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(lib.gci_reader_eof(reader));

    var result_buffer: [2]u8 = undefined;
    const length = lib.gci_reader_read(reader, &result_buffer, result_buffer.len);
    try testing.expectEqual(0, length);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "buffer internal reader fail" {
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, "1", 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 0);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var buffer: [3]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_fail_interface(&c2),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var result_buffer: [2]u8 = undefined;
    const length = lib.gci_reader_read(reader, &result_buffer, result_buffer.len);
    try testing.expectEqual(0, length);
    try testing.expect(!lib.gci_reader_eof(reader));
}

test "buffer internal reader large fail" {
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, "1", 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 0);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var buffer: [3]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(
        &context,
        lib.gci_reader_fail_interface(&c2),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var result_buffer: [10]u8 = undefined;
    const length = lib.gci_reader_read(reader, &result_buffer, result_buffer.len);
    try testing.expectEqual(0, length);
    try testing.expect(!lib.gci_reader_eof(reader));
}

test "buffer clear error" {
    const data = "122";
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var b: [2]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(&context, lib.gci_reader_fail_interface(&c2), &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer1: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer1, buffer1.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer1);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer2: [2]u8 = undefined;
    const length2 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length2);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    c2.amount_of_reads = 0; // Clear error

    // Single buffered reader never recovers
    const length3 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length3);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));
}

test "buffer clear error large" {
    const data = "1222";
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var b: [2]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_buffer_init(&context, lib.gci_reader_fail_interface(&c2), &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer1: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer1, buffer1.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer1);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer2: [3]u8 = undefined;
    const length2 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length2);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    c2.amount_of_reads = 0; // Clear error

    // Single buffered reader never recovers
    const length3 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length3);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));
}

test "double buffer init" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [4]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);
    _ = lib.gci_reader_buffer_interface(&context);
}

test "double buffer init null" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [4]u8 = undefined;
    const init_err = lib.gci_reader_double_buffer_init(
        null,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "double buffer init null buffer" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        null,
        10,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_NULL), init_err);
}

test "double buffer init small" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [2]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_BUFFER), init_err);
}

test "double buffer init odd" {
    const data = "";
    var c: lib.GciReaderString = undefined;
    const i_err = lib.gci_reader_string_init(&c, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i_err);

    var buffer: [5]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(
        &context,
        lib.gci_reader_string_interface(&c),
        &buffer,
        buffer.len,
    );
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_BUFFER), init_err);
}

test "double buffer clear error" {
    const data = "122";
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var b: [4]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(&context, lib.gci_reader_fail_interface(&c2), &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer1: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer1, buffer1.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer1);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer2: [2]u8 = undefined;
    const length2 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length2);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    c2.amount_of_reads = 0; // Clear error

    const length3 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(2, length3);
    try testing.expectEqualStrings("22", &buffer2);
    try testing.expectEqual(3, c1.current);
    try testing.expect(lib.gci_reader_eof(reader));
}

test "double buffer clear error large" {
    const data = "1222";
    var c1: lib.GciReaderString = undefined;
    const i1_err = lib.gci_reader_string_init(&c1, data, data.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i1_err);

    var c2: lib.GciReaderFail = undefined;
    const i2_err = lib.gci_reader_fail_init(&c2, lib.gci_reader_string_interface(&c1), 1);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), i2_err);

    var b: [4]u8 = undefined;
    var context: lib.GciReaderBuffer = undefined;
    const init_err = lib.gci_reader_double_buffer_init(&context, lib.gci_reader_fail_interface(&c2), &b, b.len);
    try testing.expectEqual(@as(c_uint, lib.GCI_ERROR_OK), init_err);

    const reader = lib.gci_reader_buffer_interface(&context);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer1: [1]u8 = undefined;
    const length1 = lib.gci_reader_read(reader, &buffer1, buffer1.len);
    try testing.expectEqual(1, length1);
    try testing.expectEqualStrings("1", &buffer1);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    var buffer2: [3]u8 = undefined;
    const length2 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(0, length2);
    try testing.expectEqual(2, c1.current);
    try testing.expect(!lib.gci_reader_eof(reader));

    c2.amount_of_reads = 0; // Clear error

    const length3 = lib.gci_reader_read(reader, &buffer2, buffer2.len);
    try testing.expectEqual(3, length3);
    try testing.expectEqualStrings("222", &buffer2);
    try testing.expectEqual(4, c1.current);
    try testing.expect(lib.gci_reader_eof(reader));
}
