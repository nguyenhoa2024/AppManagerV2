#import "ADKByteFormatter.h"

@implementation ADKByteFormatter

+ (NSByteCountFormatter *)sharedFormatter
{
    static NSByteCountFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSByteCountFormatter alloc] init];
        fmt.countStyle = NSByteCountFormatterCountStyleFile;
        fmt.allowedUnits = NSByteCountFormatterUseAll;
        fmt.includesUnit = YES;
        fmt.includesCount = YES;
    });
    return fmt;
}

+ (NSString *)stringFromBytes:(unsigned long long)bytes
{
    return [[self sharedFormatter] stringFromByteCount:(long long)bytes];
}

@end
