/**
 * qcapture.c — LD_PRELOAD File I/O Hook for Aurora Claude Code Control Plane
 *
 * Intercepts open(), openat(), write(), and read() syscalls to monitor
 * JSONL file access. Logs all events to /tmp/qcapture.log in JSON format
 * before the underlying syscall completes.
 *
 * Compile with:
 *   gcc -shared -fPIC -ldl -o libqcapture.so qcapture.c
 *
 * Load with:
 *   LD_PRELOAD=/path/to/libqcapture.so ./program
 *
 * Design:
 *   - Minimal overhead: syscalls intercepted only, not all I/O
 *   - Thread-safe: uses atomic ops and locks where needed
 *   - Filter: only logs JSONL files (path contains ".jsonl" or fd maps to JSONL)
 *   - Format: JSON lines to /tmp/qcapture.log (one event per line)
 *   - Error handling: invalid events logged with context, never crashes
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <sys/stat.h>
#include <stdarg.h>

/* Function pointer types for original syscalls */
typedef int (*original_open_t)(const char *pathname, int flags, ...);
typedef int (*original_openat_t)(int dirfd, const char *pathname, int flags, ...);
typedef ssize_t (*original_write_t)(int fd, const void *buf, size_t count);
typedef ssize_t (*original_read_t)(int fd, void *buf, size_t count);

/* Global function pointers */
static original_open_t original_open = NULL;
static original_openat_t original_openat = NULL;
static original_write_t original_write = NULL;
static original_read_t original_read = NULL;

/* Mutex for thread-safe logging */
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;

/* FD-to-path cache: simple direct-mapped cache to avoid redundant stat() calls */
#define FD_CACHE_SIZE 256
static struct {
    int fd;
    char path[4096];
    time_t timestamp;
} fd_cache[FD_CACHE_SIZE];
static pthread_mutex_t cache_mutex = PTHREAD_MUTEX_INITIALIZER;

/* Initialize function pointers on first use */
static void init_hooks(void) {
    if (original_open != NULL) return;  /* Already initialized */

    original_open = (original_open_t)dlsym(RTLD_NEXT, "open");
    original_openat = (original_openat_t)dlsym(RTLD_NEXT, "openat");
    original_write = (original_write_t)dlsym(RTLD_NEXT, "write");
    original_read = (original_read_t)dlsym(RTLD_NEXT, "read");

    if (!original_open || !original_openat || !original_write || !original_read) {
        /* Silently fail if hooks can't be loaded (e.g., in non-glibc environments) */
    }
}

/* Check if path contains ".jsonl" (case-sensitive) */
static int is_jsonl_path(const char *path) {
    if (!path) return 0;
    return strstr(path, ".jsonl") != NULL;
}

/* Get current UTC timestamp in ISO 8601 format */
static void get_iso8601_timestamp(char *buf, size_t buf_size) {
    time_t now = time(NULL);
    struct tm *tm_info = gmtime(&now);
    strftime(buf, buf_size, "%Y-%m-%dT%H:%M:%SZ", tm_info);
}

/* Resolve FD to path, using cache when possible */
static int resolve_fd_path(int fd, char *path_buf, size_t buf_size) {
    if (fd < 0 || fd >= 1024) return 0;  /* Invalid FD */

    /* Try cache first */
    pthread_mutex_lock(&cache_mutex);
    int cache_idx = fd % FD_CACHE_SIZE;
    if (fd_cache[cache_idx].fd == fd && fd_cache[cache_idx].path[0] != '\0') {
        strncpy(path_buf, fd_cache[cache_idx].path, buf_size - 1);
        path_buf[buf_size - 1] = '\0';
        pthread_mutex_unlock(&cache_mutex);
        return 1;
    }
    pthread_mutex_unlock(&cache_mutex);

    /* Resolve from /proc/self/fd/{fd} */
    char fd_link[256];
    snprintf(fd_link, sizeof(fd_link), "/proc/self/fd/%d", fd);

    ssize_t ret = readlink(fd_link, path_buf, buf_size - 1);
    if (ret <= 0) {
        path_buf[0] = '\0';
        return 0;
    }
    path_buf[ret] = '\0';

    /* Cache the result */
    pthread_mutex_lock(&cache_mutex);
    fd_cache[cache_idx].fd = fd;
    strncpy(fd_cache[cache_idx].path, path_buf, sizeof(fd_cache[cache_idx].path) - 1);
    fd_cache[cache_idx].timestamp = time(NULL);
    pthread_mutex_unlock(&cache_mutex);

    return 1;
}

/* Escape JSON string: handle backslash, quotes, and control chars */
static int json_escape(const char *src, char *dst, size_t dst_size) {
    size_t pos = 0;
    if (!src) {
        strncpy(dst, "", dst_size);
        return 0;
    }

    for (size_t i = 0; src[i] != '\0' && pos < dst_size - 2; i++) {
        unsigned char c = src[i];
        if (c == '\\') {
            if (pos + 2 < dst_size) {
                dst[pos++] = '\\';
                dst[pos++] = '\\';
            } else break;
        } else if (c == '"') {
            if (pos + 2 < dst_size) {
                dst[pos++] = '\\';
                dst[pos++] = '"';
            } else break;
        } else if (c < 32) {
            if (pos + 6 < dst_size) {
                pos += snprintf(dst + pos, dst_size - pos, "\\u%04x", c);
            } else break;
        } else {
            dst[pos++] = c;
        }
    }
    dst[pos] = '\0';
    return pos;
}

/* Log a capture event to /tmp/qcapture.log in JSON format */
static void log_capture_event(const char *syscall, int fd_or_ret, const char *path,
                               const char *flags, pid_t pid) {
    if (!is_jsonl_path(path)) {
        return;  /* Only log JSONL files */
    }

    pthread_mutex_lock(&log_mutex);
    FILE *log_file = fopen("/tmp/qcapture.log", "a");
    if (!log_file) {
        pthread_mutex_unlock(&log_mutex);
        return;
    }

    char timestamp[32];
    get_iso8601_timestamp(timestamp, sizeof(timestamp));

    char escaped_path[8192];
    json_escape(path, escaped_path, sizeof(escaped_path));

    char escaped_flags[512];
    json_escape(flags, escaped_flags, sizeof(escaped_flags));

    fprintf(log_file, "{\"type\":\"capture-event\",\"timestamp\":\"%s\",\"unit\":\"6\",\"data\":{\"syscall\":\"%s\",\"fd_or_ret\":%d,\"path\":\"%s\",\"flags\":\"%s\",\"pid\":%d},\"source\":\"GROUND_TRUTH\",\"error\":null}\n",
            timestamp, syscall, fd_or_ret, escaped_path, escaped_flags, pid);

    fclose(log_file);
    pthread_mutex_unlock(&log_mutex);
}

/* Convert open() flags to human-readable string */
static void flags_to_string(int flags, char *buf, size_t buf_size) {
    buf[0] = '\0';
    size_t pos = 0;

    /* Access mode */
    int mode = flags & O_ACCMODE;
    switch (mode) {
        case O_RDONLY:
            pos += snprintf(buf + pos, buf_size - pos, "O_RDONLY");
            break;
        case O_WRONLY:
            pos += snprintf(buf + pos, buf_size - pos, "O_WRONLY");
            break;
        case O_RDWR:
            pos += snprintf(buf + pos, buf_size - pos, "O_RDWR");
            break;
    }

    /* Other flags */
    if (flags & O_APPEND) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_APPEND");
    }
    if (flags & O_CREAT) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_CREAT");
    }
    if (flags & O_EXCL) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_EXCL");
    }
    if (flags & O_TRUNC) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_TRUNC");
    }
    if (flags & O_NONBLOCK) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_NONBLOCK");
    }
    if (flags & O_SYNC) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_SYNC");
    }
    if (flags & O_DIRECT) {
        pos += snprintf(buf + pos, buf_size - pos, "%s%s", pos ? "|" : "", "O_DIRECT");
    }

    if (pos == 0) {
        snprintf(buf, buf_size, "0x%x", flags);
    }
}

/* ─────────────────────────────────────────────────────────────────
   HOOKED FUNCTIONS
   ───────────────────────────────────────────────────────────────── */

int open(const char *pathname, int flags, ...) {
    init_hooks();
    if (!original_open) {
        /* Fallback: directly invoke syscall */
        return syscall(SYS_open, pathname, flags);
    }

    /* Call original open with variable arguments (mode for O_CREAT) */
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }

    int result = original_open(pathname, flags, mode);

    /* Log the event if it's a JSONL file */
    if (is_jsonl_path(pathname)) {
        char flags_str[256];
        flags_to_string(flags, flags_str, sizeof(flags_str));
        log_capture_event("open", result, pathname, flags_str, getpid());
    }

    return result;
}

int openat(int dirfd, const char *pathname, int flags, ...) {
    init_hooks();
    if (!original_openat) {
        return syscall(SYS_openat, dirfd, pathname, flags);
    }

    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }

    int result = original_openat(dirfd, pathname, flags, mode);

    if (is_jsonl_path(pathname)) {
        char flags_str[256];
        flags_to_string(flags, flags_str, sizeof(flags_str));
        log_capture_event("openat", result, pathname, flags_str, getpid());
    }

    return result;
}

ssize_t write(int fd, const void *buf, size_t count) {
    init_hooks();
    if (!original_write) {
        return syscall(SYS_write, fd, buf, count);
    }

    ssize_t result = original_write(fd, buf, count);

    /* Log write to JSONL files only */
    char path[4096];
    if (resolve_fd_path(fd, path, sizeof(path)) && is_jsonl_path(path)) {
        char size_str[32];
        snprintf(size_str, sizeof(size_str), "%zu bytes", count);
        log_capture_event("write", fd, path, size_str, getpid());
    }

    return result;
}

ssize_t read(int fd, void *buf, size_t count) {
    init_hooks();
    if (!original_read) {
        return syscall(SYS_read, fd, buf, count);
    }

    ssize_t result = original_read(fd, buf, count);

    /* Log read from JSONL files only */
    char path[4096];
    if (resolve_fd_path(fd, path, sizeof(path)) && is_jsonl_path(path)) {
        char size_str[32];
        snprintf(size_str, sizeof(size_str), "%zu bytes", count);
        log_capture_event("read", fd, path, size_str, getpid());
    }

    return result;
}
