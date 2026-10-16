#import <Cocoa/Cocoa.h>
#import "UI/CaptureOverlayView.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate, CaptureOverlayDelegate>

- (void)startAreaCapture;
- (void)startFullscreenCapture;

@end

NS_ASSUME_NONNULL_END
