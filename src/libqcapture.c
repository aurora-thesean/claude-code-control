/*
 * libqcapture.c — LD_PRELOAD File I/O Hook
 * Intercepts open(), write(), read() syscalls
 * Logs JSONL write operations to /tmp/qcapture.log
 * Minimal, zero-dependency implementation
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* Original function pointers */
static int (*original_open)(const char *pathname, int flags, ...) = NULL;
static ssize_t (*original_write)(int fd, const void *buf, size_t count) = NULL;
static ssize_t (*original_read)(int fd, void *buf, size_t count) = NULL;

/* Log file handle (per-process) */
static int logfd = -1;
static int logfile_initialized = 0;

/* Initialize original function pointers */
static void init_hooks(void) {
    if (original_open != NULL) return;

    original_open = dlsym(RTLD_NEXT, "open");
    original_write = dlsym(RTLD_NEXT, "write");
    original_read = dlsym(RTLD_NEXT, "read");
}

/* Get or initialize log file */
static int get_logfd(void) {
    if (!logfile_initialized) {
        logfile_initialized = 1;
        init_hooks();  /* Ensure hooks are initialized before calling original_open */
        if (original_open != NULL) {
            logfd = original_open("/tmp/qcapture.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
        }
    }
    return logfd;
}

/* Write JSON line to log (atomic) */
static void log_json(const char *action, const char *path, int flags,
                     int fd, size_t count) {
    if (logfd < 0) return;

    time_t now = time(NULL);
    struct tm *tm_info = gmtime(&now);
    char timestamp[32];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    /* JSON-safe string escape for path */
    char safe_path[512];
    int j = 0;
    for (int i = 0; path && path[i] && i < 500; i++) {
        if (path[i] == '"') {
            safe_path[j++] = '\\';
            safe_path[j++] = '"';
        } else if (path[i] == '\\') {
            safe_path[j++] = '\\';
            safe_path[j++] = '\\';
        } else {
            safe_path[j++] = path[i];
        }
    }
    safe_path[j] = '\0';

    /* Build JSON object */
    char json_line[1024];
    int len;
    if (strcmp(action, "open") == 0) {
        len = snprintf(json_line, sizeof(json_line),
                      "{\"timestamp\":\"%s\",\"action\":\"open\",\"path\":\"%s\",\"flags\":%d}\n",
                      timestamp, safe_path, flags);
    } else if (strcmp(action, "write") == 0) {
        len = snprintf(json_line, sizeof(json_line),
                      "{\"timestamp\":\"%s\",\"action\":\"write\",\"fd\":%d,\"count\":%zu}\n",
                      timestamp, fd, count);
    } else if (strcmp(action, "read") == 0) {
        len = snprintf(json_line, sizeof(json_line),
                      "{\"timestamp\":\"%s\",\"action\":\"read\",\"fd\":%d,\"count\":%zu}\n",
                      timestamp, fd, count);
    } else {
        return;
    }

    if (len > 0 && len < (int)sizeof(json_line) && logfd >= 0) {
        original_write(logfd, json_line, len);
    }
}

/* Intercept open() */
int open(const char *pathname, int flags, ...) {
    init_hooks();

    /* Call original */
    int result;
    va_list args;
    va_start(args, flags);
    result = original_open(pathname, flags, args);
    va_end(args);

    /* Log if JSONL file */
    if (pathname && strstr(pathname, ".jsonl") != NULL) {
        int lf = get_logfd();
        if (lf >= 0) {
            log_json("open", pathname, flags, result, 0);
        }
    }

    return result;
}

/* Intercept write() */
ssize_t write(int fd, const void *buf, size_t count) {
    init_hooks();

    /* Call original */
    ssize_t result = original_write(fd, buf, count);

    /* Log if buffer contains .jsonl marker (heuristic for JSONL writes) */
    if (result > 0 && buf != NULL) {
        const char *data = (const char *)buf;
        if (memchr(data, '{', count) != NULL || memchr(data, '}', count) != NULL) {
            int lf = get_logfd();
            if (lf >= 0) {
                log_json("write", NULL, 0, fd, count);
            }
        }
    }

    return result;
}

/* Intercept read() */
ssize_t read(int fd, void *buf, size_t count) {
    init_hooks();

    /* Call original */
    ssize_t result = original_read(fd, buf, count);

    /* Log if buffer contains .jsonl marker (heuristic) */
    if (result > 0 && buf != NULL) {
        const char *data = (const char *)buf;
        if (memchr(data, '{', result) != NULL || memchr(data, '}', result) != NULL) {
            int lf = get_logfd();
            if (lf >= 0) {
                log_json("read", NULL, 0, fd, result);
            }
        }
    }

    return result;
}
