#import "ADKTarRunner.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString *const ADKTarRunnerErrorDomain = @"ADKTarRunnerErrorDomain";

@implementation ADKTarRunner

// Runs an executable, captures stderr, returns exit status.
// Returns -1 on spawn failure.
static int _adk_run(const char *bin, const char *const argv[], NSString **stderrText)
{
    int pipefd[2];
    if (pipe(pipefd) != 0) return -1;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);
    // Discard stdout — tar prints "x file/path" lines on extract that we don't need.
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);

    pid_t pid = 0;
    int spawn_rc = posix_spawn(&pid, bin, &actions, NULL, (char *const *)argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[1]);

    if (spawn_rc != 0) {
        close(pipefd[0]);
        return -1;
    }

    NSMutableData *errBuf = [NSMutableData data];
    char buf[4096];
    ssize_t n;
    while ((n = read(pipefd[0], buf, sizeof(buf))) > 0) {
        [errBuf appendBytes:buf length:(NSUInteger)n];
    }
    close(pipefd[0]);

    int status = 0;
    waitpid(pid, &status, 0);

    if (stderrText) {
        *stderrText = [[NSString alloc] initWithData:errBuf encoding:NSUTF8StringEncoding] ?: @"";
    }

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return -1;
}

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)msg
{
    // Include exit code in the description so the progress-sheet log surfaces
    // it directly (the user only sees localizedDescription, not the code).
    NSString *prefix = (code == -1) ? @"posix_spawn failed" : [NSString stringWithFormat:@"tar exit %ld", (long)code];
    NSString *full   = msg.length ? [NSString stringWithFormat:@"%@ — %@", prefix, msg] : prefix;
    return [NSError errorWithDomain:ADKTarRunnerErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: full }];
}

+ (BOOL)createArchiveAtURL:(NSURL *)archiveURL
   fromContentsOfDirectory:(NSURL *)sourceDir
                     error:(NSError **)error
{
    if (!archiveURL.isFileURL || !sourceDir.isFileURL) {
        if (error) *error = [self errorWithCode:-1 message:@"non-file URL"];
        return NO;
    }

    const char *out = archiveURL.fileSystemRepresentation;
    const char *src = sourceDir.fileSystemRepresentation;

    // tar -czf <out> -C <src> .
    const char *argv[] = { "tar", "-czf", out, "-C", src, ".", NULL };

    NSString *err = nil;
    int rc = _adk_run("/usr/bin/tar", argv, &err);
    if (rc == 0) return YES;

    if (error) *error = [self errorWithCode:rc message:err.length ? err : @"tar create failed"];
    return NO;
}

+ (BOOL)extractArchiveAtURL:(NSURL *)archiveURL
              intoDirectory:(NSURL *)destDir
                      error:(NSError **)error
{
    if (!archiveURL.isFileURL || !destDir.isFileURL) {
        if (error) *error = [self errorWithCode:-1 message:@"non-file URL"];
        return NO;
    }

    const char *in = archiveURL.fileSystemRepresentation;
    const char *dst = destDir.fileSystemRepresentation;

    // tar -xzf <in> -C <dst>
    const char *argv[] = { "tar", "-xzf", in, "-C", dst, NULL };

    NSString *err = nil;
    int rc = _adk_run("/usr/bin/tar", argv, &err);
    if (rc == 0) return YES;

    if (error) *error = [self errorWithCode:rc message:err.length ? err : @"tar extract failed"];
    return NO;
}

@end
