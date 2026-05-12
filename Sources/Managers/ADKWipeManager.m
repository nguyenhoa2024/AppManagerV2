#import "ADKWipeManager.h"
#import "ADKFileSystem.h"

static NSString *const ADKWipeErrorDomain = @"ADKWipeErrorDomain";

@implementation ADKWipeManager

+ (instancetype)sharedManager
{
    static ADKWipeManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (BOOL)wipeApp:(ADKApp *)app error:(NSError **)error
{
    if (!app.dataContainerURL) {
        if (error) *error = [NSError errorWithDomain:ADKWipeErrorDomain code:1
                                            userInfo:@{NSLocalizedDescriptionKey:@"App has no data container"}];
        return NO;
    }
    return [ADKFileSystem wipeContentsOfDirectoryAtURL:app.dataContainerURL error:error];
}

@end
