#import "RecordingOverlayWindow.h"

@interface RecordingBorderView : NSView
@property (nonatomic, assign) NSRect cropRect;
@end

@implementation RecordingBorderView

- (void)drawRect:(NSRect)dirtyRect {
    if (NSIsEmptyRect(_cropRect)) return;
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    if (!ctx) return;

    // Draw border 2pt OUTSIDE the recorded rect so it doesn't interfere visually
    NSRect borderRect = NSInsetRect(_cropRect, -2.0, -2.0);
    
    CGContextSaveGState(ctx);
    // Subtle dark outer halo for visibility on white backgrounds
    CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithWhite:0 alpha:0.5].CGColor);
    CGContextSetLineWidth(ctx, 4.0);
    CGContextStrokeRect(ctx, borderRect);
    
    // Crisp dashed red recording border
    CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.95].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGFloat dashes[] = {6.0, 4.0};
    CGContextSetLineDash(ctx, 0, dashes, 2);
    CGContextStrokeRect(ctx, borderRect);
    CGContextRestoreGState(ctx);
}

@end

@interface RecordingControlPanel : NSPanel
@end

@implementation RecordingControlPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface RecordingOverlayWindow ()
@property (nonatomic, strong) NSWindow *borderWindow;
@property (nonatomic, strong) RecordingControlPanel *controlPanel;
@property (nonatomic, strong) NSTextField *timerLabel;
@property (nonatomic, strong) NSView *dotView;
@property (nonatomic, assign) BOOL dotBright;
@end

@implementation RecordingOverlayWindow

- (instancetype)initWithScreen:(NSScreen *)screen cropRect:(NSRect)cropRect {
    self = [super init];
    if (self) {
        if (!screen) screen = [NSScreen mainScreen];
        NSRect screenFrame = screen.frame;
        BOOL isFullscreen = NSIsEmptyRect(cropRect);
        NSRect effectiveRect = isFullscreen ? NSMakeRect(2, 2, screenFrame.size.width - 4, screenFrame.size.height - 4) : cropRect;
        
        // 1. Border Window (Click-through, excluded from capture)
        _borderWindow = [[NSWindow alloc] initWithContentRect:screenFrame
                                                    styleMask:NSWindowStyleMaskBorderless
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO
                                                       screen:screen];
        _borderWindow.level = NSStatusWindowLevel;
        _borderWindow.opaque = NO;
        _borderWindow.backgroundColor = [NSColor clearColor];
        _borderWindow.hasShadow = NO;
        _borderWindow.ignoresMouseEvents = YES;
        _borderWindow.sharingType = NSWindowSharingNone;
        _borderWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
        
        RecordingBorderView *borderView = [[RecordingBorderView alloc] initWithFrame:NSMakeRect(0, 0, screenFrame.size.width, screenFrame.size.height)];
        borderView.cropRect = effectiveRect;
        _borderWindow.contentView = borderView;
        
        // 2. Floating Control Pill (clickable stop button, excluded from capture)
        CGFloat pillW = 215.0;
        CGFloat pillH = 36.0;
        CGFloat px, py;
        
        if (isFullscreen) {
            px = screenFrame.origin.x + (screenFrame.size.width - pillW) / 2.0;
            py = screenFrame.origin.y + screenFrame.size.height - pillH - 42.0;
        } else {
            px = screenFrame.origin.x + NSMidX(effectiveRect) - pillW / 2.0;
            px = MAX(screenFrame.origin.x + 10, MIN(px, NSMaxX(screenFrame) - pillW - 10));
            py = screenFrame.origin.y + NSMinY(effectiveRect) - pillH - 12.0;
            if (py < screenFrame.origin.y + 10) {
                py = screenFrame.origin.y + NSMaxY(effectiveRect) + 12.0;
            }
            py = MAX(screenFrame.origin.y + 10, MIN(py, NSMaxY(screenFrame) - pillH - 10));
        }
        
        _controlPanel = [[RecordingControlPanel alloc] initWithContentRect:NSMakeRect(px, py, pillW, pillH)
                                                                 styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                                                   backing:NSBackingStoreBuffered
                                                                     defer:NO];
        _controlPanel.level = NSStatusWindowLevel + 1;
        _controlPanel.opaque = NO;
        _controlPanel.backgroundColor = [NSColor clearColor];
        _controlPanel.hasShadow = YES;
        _controlPanel.sharingType = NSWindowSharingNone;
        _controlPanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
        
        NSVisualEffectView *bg = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, pillW, pillH)];
        bg.material = NSVisualEffectMaterialHUDWindow;
        bg.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        bg.state = NSVisualEffectStateActive;
        bg.wantsLayer = YES;
        bg.layer.cornerRadius = 18.0;
        bg.layer.masksToBounds = YES;
        bg.layer.borderWidth = 1.0;
        bg.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.2].CGColor;
        _controlPanel.contentView = bg;
        
        // Red dot indicator
        _dotView = [[NSView alloc] initWithFrame:NSMakeRect(14, 13, 10, 10)];
        _dotView.wantsLayer = YES;
        _dotView.layer.cornerRadius = 5.0;
        _dotView.layer.backgroundColor = [NSColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0].CGColor;
        [bg addSubview:_dotView];
        _dotBright = YES;
        
        // Timer label
        _timerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(30, 8, 65, 20)];
        _timerLabel.stringValue = @"00:00";
        _timerLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightSemibold];
        _timerLabel.textColor = [NSColor whiteColor];
        _timerLabel.editable = NO;
        _timerLabel.selectable = NO;
        _timerLabel.bordered = NO;
        _timerLabel.backgroundColor = [NSColor clearColor];
        [bg addSubview:_timerLabel];
        
        // Stop button
        NSButton *stopBtn = [[NSButton alloc] initWithFrame:NSMakeRect(102, 5, 102, 26)];
        stopBtn.title = @"⏹ Dừng quay";
        stopBtn.bezelStyle = NSBezelStyleRegularSquare;
        stopBtn.bordered = NO;
        stopBtn.wantsLayer = YES;
        stopBtn.layer.cornerRadius = 13.0;
        stopBtn.layer.backgroundColor = [NSColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.9].CGColor;
        stopBtn.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
        stopBtn.contentTintColor = [NSColor whiteColor];
        stopBtn.target = self;
        stopBtn.action = @selector(stopButtonClicked:);
        [bg addSubview:stopBtn];
    }
    return self;
}

- (void)showOverlay {
    [_borderWindow orderFrontRegardless];
    [_controlPanel orderFrontRegardless];
}

- (void)updateTimerText:(NSString *)timerText {
    _timerLabel.stringValue = timerText ?: @"00:00";
    _dotBright = !_dotBright;
    _dotView.alphaValue = _dotBright ? 1.0 : 0.35;
}

- (void)stopButtonClicked:(id)sender {
    if (_onStopClicked) {
        _onStopClicked();
    }
}

- (void)closeOverlay {
    [_controlPanel orderOut:nil];
    [_borderWindow orderOut:nil];
    _controlPanel = nil;
    _borderWindow = nil;
}

@end
