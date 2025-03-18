const reader = @import("implementation/reader/reader.zig");
const writer = @import("implementation/writer/writer.zig");

pub const InterfaceReader = reader.InterfaceReader;
pub const Reader = reader.Reader;
pub const ReaderFile = reader.File;
pub const ReaderString = reader.String;
pub const ReaderBuffer = reader.Buffer;
pub const ReaderFail = reader.Fail;

pub const InterfaceWriter = writer.InterfaceWriter;
pub const Writer = writer.Writer;
pub const WriterFile = writer.File;
pub const WriterString = writer.String;
pub const WriterBuffer = writer.Buffer;

test {
    @import("std").testing.refAllDecls(@This());
}
