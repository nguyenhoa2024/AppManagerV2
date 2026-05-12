#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADKBackup : NSObject

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, copy, readonly) NSURL    *fileURL;
@property (nonatomic, copy, readonly) NSDate   *createdAt;
@property (nonatomic, assign, readonly) unsigned long long fileSize;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                 fileURL:(NSURL *)fileURL
                               createdAt:(NSDate *)createdAt
                                fileSize:(unsigned long long)fileSize NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
