#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <pthread.h>
#include <stdlib.h>

/* Mutex for thread-safe logging */
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;

/* Original write function pointer */
static ssize_t (*original_write)(int fd, const void *buf, size_t count) = NULL;

/* Get original write() function */
static void init_write(void) {
    if (original_write == NULL) {
        original_write = dlsym(RTLD_NEXT, "write");
        if (!original_write) {
            fprintf(stderr, "qcapture: Failed to find original write()\n");
            exit(1);
        }
    }
}

/* Get filename from file descriptor */
static int get_filename_from_fd(int fd, char *buffer, size_t buflen) {
    char path[256];
    ssize_t len;

    snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
    len = readlink(path, buffer, buflen - 1);

    if (len > 0) {
        buffer[len] = '\0';
        return 1;
    }
    return 0;
}

/* Check if filename ends with .jsonl */
static int is_jsonl_file(const char *filename) {
    if (!filename) return 0;

    size_t len = strlen(filename);
    if (len < 6) return 0;  /* Minimum: "x.jsonl" */

    return strcmp(filename + len - 6, ".jsonl") == 0;
}

/* Get current ISO8601 timestamp */
static void get_timestamp(char *buffer, size_t buflen) {
    time_t now;
    struct tm *tm_info;

    time(&now);
    tm_info = gmtime(&now);
    strftime(buffer, buflen, "%Y-%m-%dT%H:%M:%SZ", tm_info);
}

/* Log JSONL write to /tmp/qcapture.log */
static void log_jsonl_write(int fd, const void *buf, size_t count) {
    FILE *logfile;
    char filename[512];
    char timestamp[32];

    /* Get filename from fd */
    if (!get_filename_from_fd(fd, filename, sizeof(filename))) {
        return;  /* Failed to get filename, skip logging */
    }

    /* Only log JSONL files */
    if (!is_jsonl_file(filename)) {
        return;
    }

    get_timestamp(timestamp, sizeof(timestamp));

    /* Thread-safe file logging */
    pthread_mutex_lock(&log_mutex);

    logfile = fopen("/tmp/qcapture.log", "a");
    if (logfile) {
        /* Write as JSON line */
        fprintf(logfile, "{\"timestamp\":\"%s\",\"action\":\"write_intercept\",\"fd\":%d,\"filename\":\"%s\",\"bytes_written\":%zu}\n",
                timestamp, fd, filename, count);
        fclose(logfile);
    }

    pthread_mutex_unlock(&log_mutex);
}

/* Hooked write() function */
ssize_t write(int fd, const void *buf, size_t count) {
    init_write();

    /* Log JSONL writes */
    log_jsonl_write(fd, buf, count);

    /* Call original write() */
    return original_write(fd, buf, count);
}
