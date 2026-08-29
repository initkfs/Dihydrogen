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

enum
{
    IORING_ASYNC_CANCEL_ALL = (1U << 0),
    IORING_ASYNC_CANCEL_FD = (1U << 1),
    IORING_ASYNC_CANCEL_ANY = (1U << 2),
    IORING_ASYNC_CANCEL_FD_FIXED = (1U << 3),
}

enum io_uring_op {
	IORING_OP_NOP,
	IORING_OP_READV,
	IORING_OP_WRITEV,
	IORING_OP_FSYNC,
	IORING_OP_READ_FIXED,
	IORING_OP_WRITE_FIXED,
	IORING_OP_POLL_ADD,
	IORING_OP_POLL_REMOVE,
	IORING_OP_SYNC_FILE_RANGE,
	IORING_OP_SENDMSG,
	IORING_OP_RECVMSG,
	IORING_OP_TIMEOUT,
	IORING_OP_TIMEOUT_REMOVE,
	IORING_OP_ACCEPT,
	IORING_OP_ASYNC_CANCEL,
	IORING_OP_LINK_TIMEOUT,
	IORING_OP_CONNECT,
	IORING_OP_FALLOCATE,
	IORING_OP_OPENAT,
	IORING_OP_CLOSE,
	IORING_OP_FILES_UPDATE,
	IORING_OP_STATX,
	IORING_OP_READ,
	IORING_OP_WRITE,
	IORING_OP_FADVISE,
	IORING_OP_MADVISE,
	IORING_OP_SEND,
	IORING_OP_RECV,
	IORING_OP_OPENAT2,
	IORING_OP_EPOLL_CTL,
	IORING_OP_SPLICE,
	IORING_OP_PROVIDE_BUFFERS,
	IORING_OP_REMOVE_BUFFERS,
	IORING_OP_TEE,
	IORING_OP_SHUTDOWN,
	IORING_OP_RENAMEAT,
	IORING_OP_UNLINKAT,
	IORING_OP_MKDIRAT,
	IORING_OP_SYMLINKAT,
	IORING_OP_LINKAT,
	IORING_OP_MSG_RING,
	IORING_OP_FSETXATTR,
	IORING_OP_SETXATTR,
	IORING_OP_FGETXATTR,
	IORING_OP_GETXATTR,
	IORING_OP_SOCKET,
	IORING_OP_URING_CMD,
	IORING_OP_SEND_ZC,
	IORING_OP_SENDMSG_ZC,
	IORING_OP_READ_MULTISHOT,
	IORING_OP_WAITID,
	IORING_OP_FUTEX_WAIT,
	IORING_OP_FUTEX_WAKE,
	IORING_OP_FUTEX_WAITV,
	IORING_OP_FIXED_FD_INSTALL,
	IORING_OP_FTRUNCATE,

	/* this goes last, obviously */
	IORING_OP_LAST,
};

// struct io_uring_restriction {
// 	__u16 opcode;
// 	union {
// 		__u8 register_op; /* IORING_RESTRICTION_REGISTER_OP */
// 		__u8 sqe_op;      /* IORING_RESTRICTION_SQE_OP */
// 		__u8 sqe_flags;   /* IORING_RESTRICTION_SQE_FLAGS_* */
// 	};
// 	__u8 resv;
// 	__u32[3] resv2;
// };

// enum {
// 	/* Allow an io_uring_register(2) opcode */
// 	IORING_RESTRICTION_REGISTER_OP		= 0,

// 	/* Allow an sqe opcode */
// 	IORING_RESTRICTION_SQE_OP		= 1,

// 	/* Allow sqe flags */
// 	IORING_RESTRICTION_SQE_FLAGS_ALLOWED	= 2,

// 	/* Require sqe flags (these flags must be set on each submission) */
// 	IORING_RESTRICTION_SQE_FLAGS_REQUIRED	= 3,

// 	IORING_RESTRICTION_LAST
// };

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
