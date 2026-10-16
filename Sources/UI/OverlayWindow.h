#import <Cocoa/Cocoa.h>
#import "CaptureOverlayView.h"

NS_ASSUME_NONNULL_BEGIN

@interface OverlayWindow : NSPanel

@property (nonatomic, strong) CaptureOverlayView *overlayView;

+ (instancetype)createOverlayWindowForScreen:(NSScreen *)screen
                             backgroundImage:(NSImage *)bgImage
                                    delegate:(id<CaptureOverlayDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
