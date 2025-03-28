#include <stdint.h>
#include <limits.h>
#include <string.h>
#include <gci_writer.h>

size_t gci_writer_file_write(void const *void_context, char const *data, size_t data_size);
size_t gci_writer_string_write(void const *void_context, char const *data, size_t data_size);
size_t gci_writer_buffer_write(void const *void_context, char const *data, size_t data_size);

enum GciError gci_writer_file_init(struct GciWriterFile *context, FILE *file) {
    if (context == NULL) { return GCI_ERROR_NULL; }

    context->file = file;
    if (file == NULL) { return GCI_ERROR_NULL; }

    return GCI_ERROR_OK;
}

struct GciInterfaceWriter gci_writer_file_interface(struct GciWriterFile *writer) {
    assert(writer != NULL);
    return (struct GciInterfaceWriter) { .context = writer, .write = gci_writer_file_write };
}

size_t gci_writer_file_write(void const *context, char const *data, size_t data_size) {
    assert(context != NULL);
    assert(data != NULL);
    struct GciWriterFile *writer = (struct GciWriterFile*) context;
    return fwrite(data, sizeof(char), data_size, writer->file);
}

enum GciError gci_writer_string_init(
    struct GciWriterString *context,
    char *buffer,
    size_t buffer_size
) {
    if (context == NULL) { return GCI_ERROR_NULL; }
    context->buffer = buffer;
    if (buffer == NULL) { return GCI_ERROR_NULL; }

    context->buffer_size = buffer_size;
    context->current = 0;

    return GCI_ERROR_OK;
}

struct GciInterfaceWriter gci_writer_string_interface(struct GciWriterString *context) {
    return (struct GciInterfaceWriter) { .context = context, .write = gci_writer_string_write };
}

size_t gci_writer_string_write(void const *void_context, char const *data, size_t data_size) {
    assert(void_context != NULL);
    assert(data != NULL);

    struct GciWriterString *context = (struct GciWriterString*) void_context;
    assert(context->buffer != NULL);
    if (context->buffer_size <= 0) {
        assert(context->current == 0);
    } else {
        assert(0 <= context->current && context->current <= context->buffer_size);
    }

    size_t write_length = context->buffer_size - context->current;
    write_length = write_length > data_size ? data_size : write_length;

    memcpy(context->buffer + context->current, data, write_length);
    context->current += write_length;

    return write_length;
}

enum GciError gci_writer_buffer_init(
        struct GciWriterBuffer *context,
        struct GciInterfaceWriter writer,
        char *buffer,
        size_t buffer_size
) {
    if (context == NULL) { return GCI_ERROR_NULL; }
    context->buffer = buffer;
    if (buffer == NULL) { return GCI_ERROR_NULL; }
    if (buffer_size <= 0) { return GCI_ERROR_BUFFER; }

    context->writer = writer;
    context->buffer_size = buffer_size;
    context->current = 0;

    return GCI_ERROR_OK;
}

struct GciInterfaceWriter gci_writer_buffer_interface(struct GciWriterBuffer *context) {
    return (struct GciInterfaceWriter) { .context = context, .write = gci_writer_buffer_write };
}

size_t gci_writer_buffer_write(void const *void_context, char const *data, size_t data_size) {
    assert(void_context != NULL);
    assert(data != NULL);

    struct GciWriterBuffer *context = (struct GciWriterBuffer*) void_context;
    assert(context->buffer != NULL);
    assert(0 <= context->current && context->current < context->buffer_size);

    size_t write_length = context->buffer_size - context->current;
    write_length = write_length > data_size ? data_size : write_length;

    memcpy(context->buffer + context->current, data, write_length);
    context->current += write_length;

    if (context->current >= context->buffer_size) {
        bool flush_success = gci_writer_buffer_flush(context);
        if (!flush_success) { return 0; }

        if (data_size - write_length >= context->buffer_size) {
            size_t result = gci_writer_write(context->writer, data + write_length, data_size - write_length);
            if (result < data_size - write_length) { return write_length + result; }
        } else {
            memcpy(context->buffer, data + write_length, data_size + write_length);
        }
    }
    return data_size;
}

bool gci_writer_buffer_flush(struct GciWriterBuffer *context) {
    assert(context != NULL);
    assert(context->buffer != NULL);
    assert(0 <= context->current && context->current <= context->buffer_size);

    size_t length = context->current;
    size_t result = gci_writer_write(context->writer, context->buffer, length);
    context->current = 0;

    if (result != length) {
        return false;
    } else {
        return true;
    }
}
