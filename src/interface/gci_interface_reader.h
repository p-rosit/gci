#ifndef GCI_INTERFACE_READER_H
#define GCI_INTERFACE_READER_H
#include <assert.h>
#include <stddef.h>

typedef size_t (GciRead)(void const *context, char *buffer, size_t buffer_size);

struct GciInterfaceReader {
    void const *context;
    GciRead *read;
};

static inline size_t gci_reader_read(struct GciInterfaceReader reader, char *buffer, size_t buffer_size) {
    assert(reader.read != NULL);
    return reader.read(reader.context, buffer, buffer_size);
}

#endif
