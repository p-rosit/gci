pub const lib = @cImport({
    @cInclude("gci_common.h");
    @cInclude("gci_interface_reader.h");
    @cInclude("gci_reader.h");
    @cInclude("gci_interface_writer.h");
    @cInclude("gci_writer.h");
});

pub fn enumToError(err: lib.GciError) !void {
    switch (err) {
        lib.GCI_ERROR_OK => return,
        lib.GCI_ERROR_NULL => return error.Null,
        lib.GCI_ERROR_BUFFER => return error.Buffer,
        else => return error.Unknown,
    }
}
