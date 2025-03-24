#include "systemcalls.h"

#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>
#include <fcntl.h>
#include <stdnoreturn.h>

bool waitpid_success(pid_t pid) {
    int status;
    bool return_status = false;

    // from https://man7.org/linux/man-pages/man3/wait.3p.html#EXAMPLES
    printf("** Waiting for child %d to exit\n", (int)pid);
    do {
        pid_t return_pid = waitpid(pid, &status, WUNTRACED
#ifdef WCONTINUED       /* Not all implementations support this */
            | WCONTINUED
#endif
        );

        if (return_pid != pid) {
            if (errno == EINTR) {
                /* we were interrupted - continue */
                continue;
            } else {
                perror("!! waitpid");
                break;
            }
        }

        if (WIFEXITED(status)) {
            int child_status = WEXITSTATUS(status);

            printf("** child exited, status = %d\n", child_status);

            if (child_status == 0) {
                return_status = true;
            }
        } else if (WIFSIGNALED(status)) {
            printf("** child killed (signal %d)\n", WTERMSIG(status));

        } else if (WIFSTOPPED(status)) {
            printf("** child stopped (signal %d)\n", WSTOPSIG(status));

#ifdef WIFCONTINUED     /* Not all implementations support this */
        } else if (WIFCONTINUED(status)) {
            printf("** child continued\n");
#endif
        } else {    /* Non-standard case -- may never happen */
            printf("** Unexpected status (0x%x)\n", status);
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return return_status;
}

void execv_perror(char* const* argv) {
    execv(argv[0], argv);

    // if execv returns, we have an execv error
    perror("!! execv");
    exit(EXIT_FAILURE);
}

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{
    if (!cmd) return false;
    pid_t ret = system(cmd);

    if (WIFEXITED(ret) && !WEXITSTATUS(ret)) {
		return true;
	}

    if (errno != 0) {
        perror("system");
    }
    return false;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/

    printf("** Calling ['%s'", command[0]);
    {
        char** cc = &command[1];
        while (*cc) {
            printf(", '%s'", *cc++);
        }
        printf("]\n");
    }

    bool return_status = false;
    pid_t pid = fork();
    switch (pid) {
    case -1:
        perror("fork");
        break;
    case 0: // child
    {
        execv_perror(command);
    }
    default: // parent
        return_status = waitpid_success(pid);
        break;
    }

    va_end(args);
    printf("** returning %s\n", return_status ? "true" : "false");
    return return_status;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    /*
    * TODO
    *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
    *   redirect standard out to a file specified by outputfile.
    *   The rest of the behaviour is same as do_exec()
    *
    */

    printf("** Calling w/ redirect ['%s'", command[0]);
    {
        char** cc = &command[1];
        while (*cc) {
            printf(", '%s'", *cc++);
        }
        printf("] >> %s\n", outputfile);
    }


    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT|O_CLOEXEC, 0644);
    if (fd < 0) { 
        perror("!! open"); 
        exit(EXIT_FAILURE); 
    }

    bool return_status = false;
    pid_t pid = fork();
    switch (pid) {
    case -1:
        perror("fork");
        break;
    case 0: // child
    {
        // redirect to stdout
        if (dup2(fd, 1) < 0) { 
            perror("dup2");
            break;
        }

        execv_perror(command);
    }
    default: // parent
        return_status = waitpid_success(pid);
        break;
    }

    va_end(args);
    printf("** returning %s\n", return_status ? "true" : "false");
    return return_status;
}
