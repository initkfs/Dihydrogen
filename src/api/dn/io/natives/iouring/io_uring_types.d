module api.dn.io.natives.iouring.io_uring_types;
/**
 * Authors: initkfs
 */
import io_uring_libs;

alias unsigned = uint;

extern (C):

struct iovec;

struct io_uring_sq
{
    unsigned* khead;
    unsigned* ktail;
    // Deprecated: use `ring_mask` instead of `*kring_mask`
    unsigned* kring_mask;
    // Deprecated: use `ring_entries` instead of `*kring_entries`
    unsigned* kring_entries;
    unsigned* kflags;
    unsigned* kdropped;
    unsigned* array;
    io_uring_sqe* sqes;

    unsigned sqe_head;
    unsigned sqe_tail;

    size_t ring_sz;
    void* ring_ptr;

    unsigned ring_mask;
    unsigned ring_entries;

    unsigned[2] pad;
}

struct io_uring_cq
{
    unsigned* khead;
    unsigned* ktail;
    // Deprecated: use `ring_mask` instead of `*kring_mask`
    unsigned* kring_mask;
    // Deprecated: use `ring_entries` instead of `*kring_entries`
    unsigned* kring_entries;
    unsigned* kflags;
    unsigned* koverflow;
    io_uring_cqe* cqes;

    size_t ring_sz;
    void* ring_ptr;

    unsigned ring_mask;
    unsigned ring_entries;

    unsigned[2] pad;
}

struct io_uring
{
    io_uring_sq sq;
    io_uring_cq cq;
    unsigned flags;
    int ring_fd;

    unsigned features;
    int enter_ring_fd;
    __u8 int_flags;
    __u8[3] pad;
    unsigned pad2;
}

// enum
// {
//     IOSQE_FIXED_FILE_BIT,
//     IOSQE_IO_DRAIN_BIT,
//     IOSQE_IO_LINK_BIT,
//     IOSQE_IO_HARDLINK_BIT,
//     IOSQE_ASYNC_BIT,
//     IOSQE_BUFFER_SELECT_BIT,
//     IOSQE_CQE_SKIP_SUCCESS_BIT,
// }

// enum
// {
//     IOSQE_FIXED_FILE = 1U << IOSQE_FIXED_FILE_BIT,
//     /* issue after inflight IO */
//     IOSQE_IO_DRAIN = 1U << IOSQE_IO_DRAIN_BIT,
//     /* links next sqe */
//     IOSQE_IO_LINK = 1U << IOSQE_IO_LINK_BIT,
//     /* like LINK, but stronger */
//     IOSQE_IO_HARDLINK = 1U << IOSQE_IO_HARDLINK_BIT,
//     /* always go async */
//     IOSQE_ASYNC = 1U << IOSQE_ASYNC_BIT,
//     /* select buffer from sqe->buf_group */
//     IOSQE_BUFFER_SELECT = 1U << IOSQE_BUFFER_SELECT_BIT,
//     /* don't post CQE if request succeeded */
//     IOSQE_CQE_SKIP_SUCCESS = 1U << IOSQE_CQE_SKIP_SUCCESS_BIT,
// }
