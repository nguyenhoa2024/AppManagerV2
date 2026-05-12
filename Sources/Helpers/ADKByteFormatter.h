#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADKByteFormatter : NSObject
+ (NSString *)stringFromBytes:(unsigned long long)bytes;
@end

NS_ASSUME_NONNULL_END
