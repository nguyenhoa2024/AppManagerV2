#import "ADKFileSystem.h"
#import <sys/stat.h>
#import <dirent.h>

static unsigned long long _adk_dir_size(const char *path);

@implementation ADKFileSystem

+ (NSURL *)documentsDirectory
{
    static NSURL *dir;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSURL *> *urls = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                                                      inDomains:NSUserDomainMask];
        dir = urls.firstObject;
    });
    return dir;
}

+ (NSURL *)backupsDirectory
{
    NSURL *dir = [self.documentsDirectory URLByAppendingPathComponent:@"Backups" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:NULL];
    return dir;
}

+ (NSURL *)backupsDirectoryForBundleID:(NSString *)bundleID
{
    NSURL *dir = [self.backupsDirectory URLByAppendingPathComponent:bundleID isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:NULL];
    return dir;
}

// Walks the tree using POSIX calls — much faster than NSDirectoryEnumerator on
// containers with thousands of small files (caches, WebKit databases).
+ (unsigned long long)recursiveSizeAtURL:(NSURL *)url
{
    if (!url.isFileURL) return 0;
    const char *root = url.fileSystemRepresentation;
    if (!root) return 0;
    return _adk_dir_size(root);
}

static unsigned long long _adk_dir_size(const char *path)
{
    struct stat st;
    if (lstat(path, &st) != 0) return 0;
    if (!S_ISDIR(st.st_mode)) return (unsigned long long)st.st_size;

    DIR *dir = opendir(path);
    if (!dir) return 0;

    unsigned long long total = 0;
    struct dirent *e;
    char child[PATH_MAX];

    while ((e = readdir(dir)) != NULL) {
        const char *n = e->d_name;
        if (n[0] == '.' && (n[1] == 0 || (n[1] == '.' && n[2] == 0))) continue;
        snprintf(child, sizeof(child), "%s/%s", path, n);

        if (e->d_type == DT_DIR) {
            total += _adk_dir_size(child);
        } else if (e->d_type == DT_LNK) {
            // Skip symlink targets — measure the link itself only.
            if (lstat(child, &st) == 0) total += (unsigned long long)st.st_size;
        } else {
            if (lstat(child, &st) == 0) total += (unsigned long long)st.st_size;
        }
    }
    closedir(dir);
    return total;
}

+ (BOOL)wipeContentsOfDirectoryAtURL:(NSURL *)url error:(NSError **)error
{
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *enumErr = nil;
    NSArray<NSURL *> *children = [fm contentsOfDirectoryAtURL:url
                                   includingPropertiesForKeys:nil
                                                      options:0
                                                        error:&enumErr];
    if (!children) {
        if (error) *error = enumErr;
        return NO;
    }

    BOOL allOk = YES;
    NSError *firstErr = nil;
    for (NSURL *child in children) {
        NSError *rmErr = nil;
        if (![fm removeItemAtURL:child error:&rmErr]) {
            allOk = NO;
            if (!firstErr) firstErr = rmErr;
        }
    }
    if (!allOk && error) *error = firstErr;
    return allOk;
}

@end
