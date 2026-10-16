#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^HotKeyTriggerBlock)(void);

@interface HotKeyManager : NSObject

@property (nonatomic, copy, nullable) HotKeyTriggerBlock onHotKeyPressed;

+ (instancetype)sharedManager;

- (void)startListening;
- (void)stopListening;
- (void)updateFromSettings;

@end

NS_ASSUME_NONNULL_END
