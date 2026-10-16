#import "OverlayWindow.h"

@implementation OverlayWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

+ (instancetype)createOverlayWindowForScreen:(NSScreen *)screen
                             backgroundImage:(NSImage *)bgImage
                                    delegate:(id<CaptureOverlayDelegate>)delegate {
    NSRect frame = screen.frame;
    
    OverlayWindow *window = [[OverlayWindow alloc] initWithContentRect:frame
                                                             styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                               backing:NSBackingStoreBuffered
                                                                 defer:NO
                                                                screen:screen];
    
    [window setLevel:NSScreenSaverWindowLevel];
    [window setOpaque:NO];
    [window setBackgroundColor:[NSColor clearColor]];
    [window setHasShadow:NO];
    [window setIgnoresMouseEvents:NO];
    [window setAcceptsMouseMovedEvents:YES];
    [window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary];
    
    CaptureOverlayView *overlayView = [[CaptureOverlayView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)
                                                                backgroundImage:bgImage
                                                                    screenScale:screen.backingScaleFactor];
    overlayView.delegate = delegate;
    [window setContentView:overlayView];
    window.overlayView = overlayView;
    
    return window;
}

@end
