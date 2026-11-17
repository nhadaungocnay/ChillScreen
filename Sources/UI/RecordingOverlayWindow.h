#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordingOverlayWindow : NSObject

@property (nonatomic, copy, nullable) void (^onStopClicked)(void);

- (instancetype)initWithScreen:(NSScreen *)screen cropRect:(NSRect)cropRect;
- (void)showOverlay;
- (void)updateTimerText:(NSString *)timerText;
- (void)closeOverlay;

@end

NS_ASSUME_NONNULL_END
