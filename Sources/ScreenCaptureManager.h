#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenCaptureManager : NSObject

+ (instancetype)sharedManager;

- (nullable NSImage *)captureScreenForDisplay:(nullable NSScreen *)screen;
- (nullable NSImage *)cropImage:(NSImage *)image toRect:(NSRect)rect screenScale:(CGFloat)scale;

- (BOOL)saveImage:(NSImage *)image toPath:(NSString *)path format:(NSString *)format;
- (void)copyImageToClipboard:(NSImage *)image;
- (void)playShutterSound;
- (void)showNotificationWithTitle:(NSString *)title message:(NSString *)message;

- (BOOL)hasScreenCapturePermission;
- (void)openScreenCapturePreferences;

@end

NS_ASSUME_NONNULL_END
