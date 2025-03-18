const reader = @import("implementation/reader/reader.zig");

pub const InterfaceReader = reader.InterfaceReader;
pub const Reader = reader.Reader;
pub const ReaderFile = reader.File;
pub const ReaderString = reader.String;
pub const ReaderBuffer = reader.Buffer;
pub const ReaderFail = reader.Fail;

test {
    @import("std").testing.refAllDecls(@This());
}
