module api.dn.io.natives.iouring.io_uring;
/**
 * Authors: initkfs
 */
import api.dn.io.natives.iouring.io_uring_types;

import io_uring_libs;
import socket_libs;

extern (C):

void io_uring_close_ring_fd(io_uring* ring);
void io_uring_cq_advance(io_uring* ring, unsigned nr);
void io_uring_sqe_set_flags(io_uring_sqe* sqe,
    unsigned flags);
void io_uring_prep_provide_buffers(io_uring_sqe* sqe,
    void* addr, int len, int nr,
    int bgid, int bid);
void io_uring_free_probe(io_uring_probe* probe);
int io_uring_opcode_supported(const io_uring_probe* p,
    int op);
io_uring_probe* io_uring_get_probe_ring(io_uring* ring);
void io_uring_prep_close(io_uring_sqe* sqe,
    int fd);
int io_uring_major_version();
int io_uring_minor_version();
void io_uring_queue_exit(io_uring* ring);
void io_uring_queue_exit(io_uring* ring);
int io_uring_submit(io_uring* ring);
int io_uring_submit_and_wait(io_uring* ring, unsigned wait_nr);
int io_uring_queue_init_params(unsigned entries, io_uring* ring, io_uring_params* p);
io_uring_sqe* io_uring_get_sqe(io_uring* ring);
void io_uring_prep_write(io_uring_sqe* sqe, int fd,
    const void* buf, unsigned nbytes,
    __u64 offset);
int io_uring_peek_cqe(io_uring* ring,
    io_uring_cqe** cqe_ptr);
int io_uring_wait_cqe(io_uring* ring,
    io_uring_cqe** cqe_ptr);
void io_uring_cqe_seen(io_uring* ring, io_uring_cqe* cqe);
unsigned io_uring_peek_batch_cqe(io_uring* ring,
    io_uring_cqe** cqes, unsigned count);
void* io_uring_cqe_get_data(io_uring_cqe* cqe);
__u64 io_uring_cqe_get_data64(io_uring_cqe* cqe);
void io_uring_prep_accept(io_uring_sqe* sqe, int fd,
    sockaddr* addr,
    socklen_t* addrlen, int flags);
void io_uring_prep_recv(io_uring_sqe* sqe, int sockfd,
    void* buf, size_t len, int flags);
void io_uring_prep_send(io_uring_sqe* sqe, int sockfd,
    const void* buf, size_t len, int flags);
void io_uring_prep_send_zc(io_uring_sqe* sqe, int sockfd,
    const void* buf, size_t len, int flags, uint zcflags);
void io_uring_sqe_set_data(io_uring_sqe* sqe, void* data);
void io_uring_sqe_set_data(io_uring_sqe* sqe, __u64 data);
void io_uring_prep_cancel(io_uring_sqe* sqe, void* user_data, int flags);
void io_uring_prep_splice(io_uring_sqe* sqe, int fd_in, int64_t off_in, int fd_out, int64_t off_out, uint nbytes, uint splice_flags);
void io_uring_prep_shutdown(io_uring_sqe* sqe, int sockfd, int how);
void io_uring_prep_read(io_uring_sqe* sqe, int fd, void* buf, uint nbytes, __u64 offset);
int io_uring_register_restrictions(io_uring *ring, io_uring_restriction *res, uint nr_res);
int io_uring_enable_rings(io_uring *ring);

import time_libs;

void io_uring_prep_timeout(io_uring_sqe* sqe,
    __kernel_timespec* ts,
    uint count,
    uint flags);

void io_uring_prep_timeout_remove(io_uring_sqe* sqe, __u64 user_data, uint flags);

enum TimeoutFlags : uint
{
    IORING_TIMEOUT_ABS = (1U << 0),
    IORING_TIMEOUT_UPDATE = (1U << 1),
    IORING_TIMEOUT_BOOTTIME = (1U << 2),
    IORING_TIMEOUT_REALTIME = (1U << 3),
    IORING_LINK_TIMEOUT_UPDATE = (1U << 4),
    IORING_TIMEOUT_ETIME_SUCCESS = (1U << 5),
    IORING_TIMEOUT_MULTISHOT = (1U << 6),
    IORING_TIMEOUT_CLOCK_MASK = (IORING_TIMEOUT_BOOTTIME | IORING_TIMEOUT_REALTIME),
    IORING_TIMEOUT_UPDATE_MASK = (IORING_TIMEOUT_UPDATE | IORING_LINK_TIMEOUT_UPDATE)
}
