#ifndef GCI_WRITER_H
#define GCI_WRITER_H
#include <stdbool.h>
#include <stdio.h>
#include <gci_common.h>
#include <gci_interface_writer.h>

// A writer that writes to a file, use `gci_writer_file` to initialize.
struct GciWriterFile {
    FILE *file;
};

// Initializes a `struct GciWriterFile`.
//
// Params:
//  context:    Single item pointer to `struct GciWriterFile`.
//  file:       Single item pointer to file, if call succeeds owned by `writer`.
//
// Return:
//  GCI_ERROR_OK: Call succeeded
//  GCI_ERROR_NULL: `file` is null.
enum GciError gci_writer_file_init(struct GciWriterFile *context, FILE *file);

// Makes a writer interface from an already initialized `struct GciWriterFile`
// the returned writer owns the passed in `context`.
struct GciInterfaceWriter gci_writer_file_interface(struct GciWriterFile *context);

// A writer that writes to a char buffer. The `current` field keeps track
// of how many bytes have been written so far
struct GciWriterString {
    char *buffer;
    size_t buffer_size;
    size_t current;
};

// Initializes a `struct GciWriterString`.
//
// Params:
//  context:        Single item pointer to `struct GciWriterString`.
//  buffer:         Pointer to at least as many items as specified by
//                  `buffer_size`, owned by `writer` if call succeeds.
//  buffer_size:    Specifies at most how many items `buffer` points to.
//
// Return:
//  GCI_ERROR_OK:       Call succeeded.
//  GCI_ERROR_NULL:     `buffer` is null.
enum GciError gci_writer_string_init(
    struct GciWriterString *context,
    char *buffer,
    size_t buffer_size
);

// Makes a writer interface from an already initialized `struct GciWriterString`
// the returned writer owns the passed in `context`.
struct GciInterfaceWriter gci_writer_string_interface(struct GciWriterString *context);

// A writer that buffers any calls to an internal writer.
struct GciWriterBuffer {
    struct GciInterfaceWriter writer;
    char *buffer;
    size_t buffer_size;
    size_t current;
};

// Initializes a `struct GciWriterBuffer`
//
// Params:
//  context:        Single item pointer to `struct GciWriterBuffer`.
//  writer:         Valid write struct, owned by `context` if call succeeds.
//  buffer:         Pointer to at least as many items as specified by
//                  `buffer_size`, owned by `writer` if call succeeds.
//  buffer_size:    Specifies at most how many items `buffer` points to.
//
// Return:
//  GCI_ERROR_OK:       Call succeeded.
//  GCI_ERROR_NULL:     Returned in the following situations:
//      1. `context` is null.
//      2. `buffer` is null.
//  GCI_ERROR_BUFFER:   `buffer_size` <= 0.
enum GciError gci_writer_buffer_init(
    struct GciWriterBuffer *context,
    struct GciInterfaceWriter writer,
    char *buffer,
    size_t buffer_size
);

// Makes a writer interface from an already initialized `struct GciWriterBuffer`
// the returned writer owns the passed in `context`.
struct GciInterfaceWriter gci_writer_buffer_interface(struct GciWriterBuffer *context);

// Flushes the internal buffer by writing everything in it to the internal writer.
// Returns true if the call succeded and false if call failed.
bool gci_writer_buffer_flush(struct GciWriterBuffer *context);

#endif
