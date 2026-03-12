/**
 * test-qcapture-integration.c — Integration test for qcapture LD_PRELOAD hook
 *
 * Writes to a JSONL file to verify the hook captures the syscalls.
 *
 * Compile with:
 *   gcc -o test-qcapture-integration test-qcapture-integration.c
 *
 * Run with:
 *   LD_PRELOAD=/path/to/libqcapture.so ./test-qcapture-integration /tmp/test.jsonl
 *
 * Verify output:
 *   cat /tmp/qcapture.log | jq .
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

int main(int argc, char *argv[]) {
    const char *filename = argc > 1 ? argv[1] : "/tmp/test-qcapture.jsonl";

    printf("Writing to: %s\n", filename);

    /* Open file for writing */
    int fd = open(filename, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    printf("File descriptor: %d\n", fd);

    /* Write some JSON lines */
    const char *test_data[] = {
        "{\"event\": \"test1\", \"timestamp\": \"2026-03-12T10:00:00Z\"}\n",
        "{\"event\": \"test2\", \"timestamp\": \"2026-03-12T10:00:01Z\"}\n",
        "{\"event\": \"test3\", \"timestamp\": \"2026-03-12T10:00:02Z\"}\n"
    };

    for (size_t i = 0; i < sizeof(test_data) / sizeof(test_data[0]); i++) {
        ssize_t written = write(fd, test_data[i], strlen(test_data[i]));
        if (written < 0) {
            perror("write");
            return 1;
        }
        printf("Wrote %zd bytes\n", written);
    }

    /* Close file */
    if (close(fd) < 0) {
        perror("close");
        return 1;
    }

    printf("Closed file descriptor\n");

    /* Try to read it back */
    printf("\nReading back:\n");
    fd = open(filename, O_RDONLY);
    if (fd >= 0) {
        char buf[512];
        ssize_t nread;
        while ((nread = read(fd, buf, sizeof(buf))) > 0) {
            fwrite(buf, 1, nread, stdout);
        }
        close(fd);
    }

    printf("\nDone. Check /tmp/qcapture.log for capture events.\n");
    return 0;
}
