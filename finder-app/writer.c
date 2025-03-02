/** writer WRITEFILE WRITESTR
 Create a WRITEFILE by full path with WRITESTR content */
#include <syslog.h>
#include <stdio.h>
#include <errno.h>

int main(int argc, char** argv) {
    openlog(NULL,0,LOG_USER);
    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: expected 3 but %d provided", argc);
        return 1;
    }

    const char* filename = argv[1];
    const char* string = argv[2];

    FILE* file = fopen(filename, "w");
    if (!file) {
        syslog(LOG_ERR, "Error opening file %s: %d", filename, errno);
        return 1;
    }

    syslog(LOG_DEBUG, "Writing %s to %s", string, filename);
    int rc = fputs(string, file);
    if (!rc) {
        syslog(LOG_ERR, "Error writing to %s: %d", filename, errno);
        return 1;
    }

    /* cleanup */
    fclose(file);
    closelog();
    return 0;
}