#import "ADKZipRunner.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <fcntl.h>

extern char **environ;

static NSString *const ADKZipRunnerErrorDomain = @"ADKZipRunnerErrorDomain";

static int _adk_run(const char *bin, const char *const argv[],
                    const char *cwd, NSString **stderrText);

@implementation ADKZipRunner

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)msg
{
    NSString *prefix = (code == -1)
        ? @"posix_spawn failed"
        : [NSString stringWithFormat:@"zip exit %ld", (long)code];
    NSString *full = msg.length ? [NSString stringWithFormat:@"%@ — %@", prefix, msg] : prefix;
    return [NSError errorWithDomain:ADKZipRunnerErrorDomain
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

    // zip -r -X -q <out> .   (recurse, no extra extras, quiet)
    const char *argv[] = { "zip", "-r", "-X", "-q", out, ".", NULL };

    NSString *err = nil;
    int rc = _adk_run("/usr/bin/zip", argv, src, &err);
    if (rc == 0) return YES;
    if (error) *error = [self errorWithCode:rc message:err.length ? err : @"zip create failed"];
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

    // unzip -qq -o <in> -d <dst>   (quiet, overwrite)
    const char *argv[] = { "unzip", "-qq", "-o", in, "-d", dst, NULL };

    NSString *err = nil;
    int rc = _adk_run("/usr/bin/unzip", argv, NULL, &err);
    if (rc == 0) return YES;
    if (error) *error = [self errorWithCode:rc message:err.length ? err : @"unzip failed"];
    return NO;
}

#pragma mark - posix_spawn helper

static int _adk_run(const char *bin, const char *const argv[],
                    const char *cwd, NSString **stderrText)
{
    int pipefd[2];
    if (pipe(pipefd) != 0) return -1;

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addclose(&actions, pipefd[0]);
    posix_spawn_file_actions_adddup2(&actions, pipefd[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    if (cwd) {
        // posix_spawn doesn't accept a working dir prior to iOS 13.4; emulate via chdir
        // in the parent process is unsafe. Use chdir-then-spawn-then-restore pattern.
        // Acceptable because backup runs serialized on its own background queue.
    }

    pid_t pid = 0;
    int saved_cwd = -1;
    if (cwd) {
        saved_cwd = open(".", O_RDONLY);
        if (chdir(cwd) != 0) {
            close(pipefd[1]); close(pipefd[0]);
            if (saved_cwd >= 0) close(saved_cwd);
            posix_spawn_file_actions_destroy(&actions);
            return -1;
        }
    }
    int spawn_rc = posix_spawn(&pid, bin, &actions, NULL, (char *const *)argv, environ);
    if (cwd && saved_cwd >= 0) {
        fchdir(saved_cwd);
        close(saved_cwd);
    }
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

@end
