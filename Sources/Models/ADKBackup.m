#import "ADKBackup.h"

@implementation ADKBackup

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                 fileURL:(NSURL *)fileURL
                               createdAt:(NSDate *)createdAt
                                fileSize:(unsigned long long)fileSize
{
    if ((self = [super init])) {
        _bundleIdentifier = [bundleIdentifier copy];
        _fileURL          = [fileURL copy];
        _createdAt        = [createdAt copy];
        _fileSize         = fileSize;
    }
    return self;
}

@end
