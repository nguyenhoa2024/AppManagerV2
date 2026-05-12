#import "ADKApp.h"

@implementation ADKApp

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                             displayName:(NSString *)displayName
                            shortVersion:(NSString *)shortVersion
                           bundleVersion:(NSString *)bundleVersion
                               bundleURL:(NSURL *)bundleURL
                        dataContainerURL:(NSURL *)dataContainerURL
                     primaryIconFileName:(NSString *)primaryIconFileName
                                 appType:(ADKAppType)appType
{
    if ((self = [super init])) {
        _bundleIdentifier    = [bundleIdentifier copy];
        _displayName         = [displayName copy];
        _shortVersion        = [shortVersion copy];
        _bundleVersion       = [bundleVersion copy];
        _bundleURL           = [bundleURL copy];
        _dataContainerURL    = [dataContainerURL copy];
        _primaryIconFileName = [primaryIconFileName copy];
        _appType             = appType;
        _cachedDataSize      = 0;
        _cachedDataSizeValid = NO;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ADKApp %@ (%@) v%@>",
            self.displayName, self.bundleIdentifier, self.shortVersion ?: @"?"];
}

- (NSUInteger)hash { return self.bundleIdentifier.hash; }

- (BOOL)isEqual:(id)other
{
    if (other == self) return YES;
    if (![other isKindOfClass:[ADKApp class]]) return NO;
    return [self.bundleIdentifier isEqualToString:((ADKApp *)other).bundleIdentifier];
}

@end
