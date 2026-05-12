#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ADKAppType) {
    ADKAppTypeUser     = 0,
    ADKAppTypeSystem   = 1,
    ADKAppTypeInternal = 2,
};

@interface ADKApp : NSObject

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *shortVersion;
@property (nonatomic, copy, readonly) NSString *bundleVersion;
@property (nonatomic, copy, readonly) NSURL    *bundleURL;
@property (nonatomic, copy, readonly, nullable) NSURL *dataContainerURL;
@property (nonatomic, copy, readonly, nullable) NSString *primaryIconFileName;
@property (nonatomic, assign, readonly) ADKAppType appType;

// Filled in lazily by the repository on first measure.
@property (nonatomic, assign) unsigned long long cachedDataSize;
@property (nonatomic, assign) BOOL cachedDataSizeValid;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                             displayName:(NSString *)displayName
                            shortVersion:(nullable NSString *)shortVersion
                           bundleVersion:(nullable NSString *)bundleVersion
                               bundleURL:(NSURL *)bundleURL
                        dataContainerURL:(nullable NSURL *)dataContainerURL
                     primaryIconFileName:(nullable NSString *)primaryIconFileName
                                 appType:(ADKAppType)appType NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
