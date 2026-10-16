#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsWindowController : NSWindowController

+ (instancetype)sharedController;
- (void)showSettingsWindow;

@end

NS_ASSUME_NONNULL_END
