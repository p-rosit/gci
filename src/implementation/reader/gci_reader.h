#ifndef CON_READER_H
#define CON_READER_H
#include <stdio.h>
#include <gci_common.h>
#include <gci_interface_reader.h>

struct GciReaderFail {
    struct GciInterfaceReader reader;
    size_t reads_before_fail;
    size_t amount_of_reads;
};

enum GciError gci_reader_fail_init(struct GciReaderFail *context, struct GciInterfaceReader reader, size_t reads_before_fail);

struct GciInterfaceReader gci_reader_fail_interface(struct GciReaderFail *context);

struct GciReaderFile {
    FILE *file;
};

enum GciError gci_reader_file_init(struct GciReaderFile *context, FILE *file);
struct GciInterfaceReader gci_reader_file_interface(struct GciReaderFile *context);

struct GciReaderString {
    char const *buffer;
    size_t buffer_size;
    size_t current;
};

enum GciError gci_reader_string_init(
    struct GciReaderString *context,
    char const *buffer,
    size_t buffer_size
);

struct GciInterfaceReader gci_reader_string_interface(struct GciReaderString *context);

struct GciReaderBuffer {
    struct GciInterfaceReader reader;
    char *buffer;
    char *next_read;
    size_t buffer_size;
    size_t current;
    size_t length_read;
};

enum GciError gci_reader_buffer_init(
    struct GciReaderBuffer *context,
    struct GciInterfaceReader reader,
    char *buffer,
    size_t buffer_size
);
enum GciError gci_reader_double_buffer_init(
    struct GciReaderBuffer *context,
    struct GciInterfaceReader reader,
    char *buffer,
    size_t buffer_size
);

struct GciInterfaceReader gci_reader_buffer_interface(struct GciReaderBuffer *context);

#endif
