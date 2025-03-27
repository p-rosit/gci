#include <limits.h>
#include <string.h>
#include <stdbool.h>
#include <gci_reader.h>

size_t gci_reader_fail_read(void const *context, char *buffer, size_t buffer_size);
size_t gci_reader_file_read(void const *context, char *buffer, size_t buffer_size);
size_t gci_reader_string_read(void const *context, char *buffer, size_t buffer_size);
size_t gci_reader_buffer_read(void const *context, char *buffer, size_t buffer_size);
bool gci_reader_fail_eof(void const *context);
bool gci_reader_file_eof(void const *context);
bool gci_reader_string_eof(void const *context);
bool gci_reader_buffer_eof(void const *context);

enum GciError gci_reader_fail_init(struct GciReaderFail *context, struct GciInterfaceReader reader, size_t reads_before_fail) {
    if (context == NULL) { return GCI_ERROR_NULL; }

    context->reader = reader;
    context->reads_before_fail = reads_before_fail;
    context->amount_of_reads = 0;

    return GCI_ERROR_OK;
}

struct GciInterfaceReader gci_reader_fail_interface(struct GciReaderFail *context) {
    return (struct GciInterfaceReader) {
        .context = context,
        .read = gci_reader_fail_read,
        .eof = gci_reader_fail_eof,
    };
}

size_t gci_reader_fail_read(void const *void_context, char *buffer, size_t buffer_size) {
    assert(void_context != NULL);
    struct GciReaderFail *context = (struct GciReaderFail*) void_context;

    bool error = context->amount_of_reads >= context->reads_before_fail;
    size_t length = 0;

    if (!error) {
        context->amount_of_reads += 1;

        length = gci_reader_read(context->reader, buffer, buffer_size);
        assert(length >= 0 || buffer_size == 0);
    } else {
        memset(buffer, 0, buffer_size);
    }

    return length;
}

bool gci_reader_fail_eof(void const *void_context) {
    assert(void_context != NULL);
    struct GciReaderFail *context = (struct GciReaderFail*) void_context;
    return gci_reader_eof(context->reader);
}

enum GciError gci_reader_file_init(struct GciReaderFile *context, FILE *file) {
    if (context == NULL) { return GCI_ERROR_NULL; }

    context->file = file;
    if (file == NULL) { return GCI_ERROR_NULL; }

    return GCI_ERROR_OK;
}

struct GciInterfaceReader gci_reader_file_interface(struct GciReaderFile *context) {
    return (struct GciInterfaceReader) {
        .context = context,
        .read = gci_reader_file_read,
        .eof = gci_reader_file_eof,
    };
}

size_t gci_reader_file_read(void const *void_context, char *buffer, size_t buffer_size) {
    assert(void_context != NULL);
    struct GciReaderFile *context = (struct GciReaderFile*) void_context;

    assert(buffer != NULL);
    size_t read_length = fread(buffer, sizeof(char), buffer_size, context->file);

    assert(read_length <= buffer_size);
    return read_length;
}

bool gci_reader_file_eof(void const *void_context) {
    assert(void_context != NULL);
    struct GciReaderFile *context = (struct GciReaderFile*) void_context;
    return feof(context->file);
}

enum GciError gci_reader_string_init(struct GciReaderString *context, char const *buffer, size_t buffer_size) {
    if (context == NULL) { return GCI_ERROR_NULL; }

    context->buffer = NULL;
    if (buffer == NULL) { return GCI_ERROR_NULL; }
    if (buffer_size < 0) { return GCI_ERROR_BUFFER; }

    context->buffer = buffer;
    context->buffer_size = buffer_size;
    context->current = 0;

    return GCI_ERROR_OK;
}

struct GciInterfaceReader gci_reader_string_interface(struct GciReaderString *context) {
    return (struct GciInterfaceReader) {
        .context = context,
        .read = gci_reader_string_read,
        .eof = gci_reader_string_eof,
    };
}

size_t gci_reader_string_read(void const *void_context, char *buffer, size_t buffer_size) {
    assert(void_context != NULL);
    struct GciReaderString *context = (struct GciReaderString*) void_context;

    assert(0 <= context->current && context->current <= context->buffer_size);
    if (context->current >= context->buffer_size) {
        return 0;
    }

    size_t read_length = context->buffer_size - context->current;
    read_length = read_length > buffer_size ? buffer_size : read_length;

    assert(buffer != NULL);
    assert(context->buffer != NULL);
    memcpy(buffer, context->buffer + context->current, read_length);
    context->current += read_length;

    assert(read_length <= buffer_size);
    return read_length;
}

bool gci_reader_string_eof(void const *void_context) {
    assert(void_context != NULL);
    struct GciReaderString *context = (struct GciReaderString*) void_context;
    return context->current >= context->buffer_size;
}

enum GciError gci_reader_buffer_init(
    struct GciReaderBuffer *context,
    struct GciInterfaceReader reader,
    char *buffer,
    size_t buffer_size
) {
    if (context == NULL) { return GCI_ERROR_NULL; }
    if (buffer == NULL) { return GCI_ERROR_NULL; }
    if (buffer_size <= 1) { return GCI_ERROR_BUFFER; }

    context->reader = reader;
    context->buffer = buffer;
    context->next_read = buffer;
    context->buffer_size = buffer_size;
    context->current = 0;
    context->length_read = 0;

    return GCI_ERROR_OK;
}

enum GciError gci_reader_double_buffer_init(
    struct GciReaderBuffer *context,
    struct GciInterfaceReader reader,
    char *buffer,
    size_t buffer_size
) {
    if (context == NULL) { return GCI_ERROR_NULL; }
    if (buffer == NULL) { return GCI_ERROR_NULL; }

    size_t half_size = buffer_size / 2;
    if (half_size <= 1 || buffer_size % 2 != 0) { return GCI_ERROR_BUFFER; }

    context->reader = reader;
    context->buffer = buffer;
    context->next_read = buffer + half_size;
    context->buffer_size = half_size;
    context->current = 0;
    context->length_read = 0;

    return GCI_ERROR_OK;
}

struct GciInterfaceReader gci_reader_buffer_interface(struct GciReaderBuffer *context) {
    return (struct GciInterfaceReader) {
        .context = context,
        .read = gci_reader_buffer_read,
        .eof = gci_reader_buffer_eof,
    };
}

size_t gci_reader_buffer_read(void const *void_context, char *buffer, size_t buffer_size) {
    assert(void_context != NULL);

    struct GciReaderBuffer *context = (struct GciReaderBuffer*) void_context;
    assert(0 <= context->current && context->current <= context->buffer_size);
    assert(0 <= context->length_read && context->length_read <= context->buffer_size);
    assert(context->current <= context->length_read) ;

    if (context->next_read == NULL) {
        return 0;
    }

    size_t read_length = context->length_read - context->current;
    read_length = read_length > buffer_size ? buffer_size : read_length;

    assert(buffer != NULL);
    assert(context->buffer != NULL);
    memcpy(buffer, context->buffer + context->current, read_length);
    context->current += read_length;

    if (context->current >= context->length_read) {
        assert(read_length <= buffer_size);
        size_t length_left = buffer_size - read_length;

        if (buffer_size - read_length >= context->buffer_size) {
            size_t length = gci_reader_read(context->reader, buffer + read_length, length_left);
            if (length == 0) {
                if (context->buffer == context->next_read) {
                    context->next_read = NULL;
                }
                context->current -= read_length;
                read_length = 0;
            } else {
                read_length += length;
            }
        } else {
            size_t length = gci_reader_read(context->reader, context->next_read, context->buffer_size);
            if (length == 0) {
                if (context->buffer == context->next_read) {
                    context->next_read = NULL;
                }

                assert(read_length <= context->current);
                context->current -= read_length;
                read_length = 0;
            } else {
                char *temp = context->buffer;
                context->buffer = context->next_read;
                context->next_read = temp;

                context->length_read = length;

                size_t next_length = context->length_read > length_left ? length_left : context->length_read;

                memcpy(buffer + read_length, context->buffer, next_length);
                context->current = next_length;

                read_length += next_length;
            }
        }
    }

    assert(read_length <= buffer_size);
    return read_length;
}

bool gci_reader_buffer_eof(void const *void_context) {
    assert(void_context != NULL);
    struct GciReaderBuffer *context = (struct GciReaderBuffer*) void_context;
    return (context->current >= context->length_read) && gci_reader_eof(context->reader);
}
