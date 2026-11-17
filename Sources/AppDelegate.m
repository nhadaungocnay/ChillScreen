#import "AppDelegate.h"
#import "HotKeyManager.h"
#import "ScreenCaptureManager.h"
#import "ScreenRecorderManager.h"
#import "SettingsManager.h"
#import "UI/OverlayWindow.h"
#import "UI/SettingsWindowController.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong, nullable) OverlayWindow *activeOverlayWindow;
@property (nonatomic, strong, nullable) NSScreen *activeCaptureScreen;
@property (nonatomic, strong, nullable) NSMenuItem *stopRecordingMenuItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"[ChillScreen] App launched in background.");
    
    // Ensure save directory is ready
    [[SettingsManager sharedManager] ensureSaveDirectoryExists];
    
    // Setup Menu Bar Icon
    [self setupStatusItem];
    
    // Setup Global Hotkey listener
    HotKeyManager *hkm = [HotKeyManager sharedManager];
    __weak typeof(self) weakSelf = self;
    hkm.onHotKeyPressed = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startAreaCapture];
        });
    };
    hkm.onRecordHotKeyPressed = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([ScreenRecorderManager sharedManager].isRecording) {
                [weakSelf stopRecording];
            } else {
                [weakSelf startAreaRecording];
            }
        });
    };
    [hkm startListening];
    
    // Setup ScreenRecorder callbacks
    ScreenRecorderManager *srm = [ScreenRecorderManager sharedManager];
    srm.onRecordingTimerTick = ^(NSString *formattedTime) {
        weakSelf.statusItem.button.title = [NSString stringWithFormat:@" 🔴 %@", formattedTime];
        if (weakSelf.stopRecordingMenuItem) {
            weakSelf.stopRecordingMenuItem.title = [NSString stringWithFormat:@"⏹ Dừng quay video (%@)", formattedTime];
        }
    };
    srm.onRecordingFinished = ^(NSString * _Nullable outputPath, NSError * _Nullable error) {
        weakSelf.statusItem.button.title = @"";
        [weakSelf buildStatusMenu];
    };
    
    // Listen for settings change to update menu shortcuts
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:kSettingsChangedNotification
                                               object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[HotKeyManager sharedManager] stopListening];
}

- (void)setupStatusItem {
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = nil;
    if (@available(macOS 11.0, *)) {
        icon = [NSImage imageWithSystemSymbolName:@"camera.viewfinder" accessibilityDescription:@"ChillScreen"];
    }
    if (!icon) {
        // Fallback custom drawing
        icon = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            [[NSColor blackColor] setStroke];
            NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(dstRect, 2, 2) xRadius:3 yRadius:3];
            [bp setLineWidth:1.5];
            [bp stroke];
            
            NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(6, 6, 6, 6)];
            [circle setLineWidth:1.5];
            [circle stroke];
            return YES;
        }];
    }
    [icon setTemplate:YES];
    _statusItem.button.image = icon;
    
    [self buildStatusMenu];
}

- (void)buildStatusMenu {
    _statusMenu = [[NSMenu alloc] initWithTitle:@"ChillScreen"];
    _stopRecordingMenuItem = nil;
    
    SettingsManager *sm = [SettingsManager sharedManager];
    
    if ([ScreenRecorderManager sharedManager].isRecording) {
        _stopRecordingMenuItem = [[NSMenuItem alloc] initWithTitle:@"⏹ Dừng quay video"
                                                            action:@selector(stopRecording)
                                                     keyEquivalent:@""];
        _stopRecordingMenuItem.target = self;
        [_statusMenu addItem:_stopRecordingMenuItem];
        [_statusMenu addItem:[NSMenuItem separatorItem]];
    }
    
    NSString *hkTitle = [NSString stringWithFormat:@"Chụp vùng màn hình (%@)", [sm formattedHotkeyString]];
    NSMenuItem *captureItem = [[NSMenuItem alloc] initWithTitle:hkTitle
                                                         action:@selector(startAreaCapture)
                                                  keyEquivalent:@""];
    captureItem.target = self;
    [_statusMenu addItem:captureItem];
    
    NSMenuItem *fullItem = [[NSMenuItem alloc] initWithTitle:@"Chụp toàn màn hình"
                                                      action:@selector(startFullscreenCapture)
                                               keyEquivalent:@""];
    fullItem.target = self;
    [_statusMenu addItem:fullItem];
    
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSString *recTitle = [NSString stringWithFormat:@"Quay vùng màn hình (%@)", [sm formattedRecordHotkeyString]];
    NSMenuItem *recAreaItem = [[NSMenuItem alloc] initWithTitle:recTitle
                                                         action:@selector(startAreaRecording)
                                                  keyEquivalent:@""];
    recAreaItem.target = self;
    [_statusMenu addItem:recAreaItem];
    
    NSMenuItem *recFullItem = [[NSMenuItem alloc] initWithTitle:@"Quay toàn màn hình"
                                                         action:@selector(startFullscreenRecording)
                                                  keyEquivalent:@""];
    recFullItem.target = self;
    [_statusMenu addItem:recFullItem];
    
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:@"Mở thư mục lưu ảnh & video"
                                                        action:@selector(openSaveFolder)
                                                 keyEquivalent:@""];
    folderItem.target = self;
    [_statusMenu addItem:folderItem];
    
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Cài đặt..."
                                                          action:@selector(openSettings)
                                                   keyEquivalent:@","];
    settingsItem.target = self;
    [_statusMenu addItem:settingsItem];
    
    [_statusMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Thoát ChillScreen"
                                                      action:@selector(quitApp)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [_statusMenu addItem:quitItem];
    
    _statusItem.menu = _statusMenu;
}

- (void)settingsDidChange:(NSNotification *)note {
    [self buildStatusMenu];
}

#pragma mark - Capture Logic

- (NSScreen *)screenUnderMouse {
    NSPoint mouseLoc = [NSEvent mouseLocation];
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(mouseLoc, screen.frame)) {
            return screen;
        }
    }
    return [NSScreen mainScreen];
}

- (void)startAreaCapture {
    if (_activeOverlayWindow || [ScreenRecorderManager sharedManager].isRecording) {
        // Already active
        return;
    }
    
    NSScreen *screen = [self screenUnderMouse];
    _activeCaptureScreen = screen;
    
    // Capture screen first
    NSImage *screenshot = [[ScreenCaptureManager sharedManager] captureScreenForDisplay:screen];
    if (!screenshot) {
        NSLog(@"[ChillScreen] Failed to capture screen.");
        [[ScreenCaptureManager sharedManager] showNotificationWithTitle:@"ChillScreen"
                                                                message:@"Không thể chụp màn hình. Vui lòng kiểm tra quyền Screen Recording."];
        return;
    }
    
    _activeOverlayWindow = [OverlayWindow createOverlayWindowForScreen:screen
                                                       backgroundImage:screenshot
                                                              delegate:self];
    
    [NSApp activateIgnoringOtherApps:YES];
    [_activeOverlayWindow makeKeyAndOrderFront:nil];
}

- (void)startAreaRecording {
    if ([ScreenRecorderManager sharedManager].isRecording) {
        [self stopRecording];
        return;
    }
    [self startAreaCapture];
}

- (void)startFullscreenRecording {
    if ([ScreenRecorderManager sharedManager].isRecording) {
        [self stopRecording];
        return;
    }
    NSScreen *screen = [self screenUnderMouse];
    [[ScreenRecorderManager sharedManager] startRecordingScreen:screen cropRect:NSZeroRect];
    [self buildStatusMenu];
}

- (void)stopRecording {
    [[ScreenRecorderManager sharedManager] stopRecording];
}

- (void)startFullscreenCapture {
    NSScreen *screen = [self screenUnderMouse];
    NSImage *screenshot = [[ScreenCaptureManager sharedManager] captureScreenForDisplay:screen];
    if (!screenshot) return;
    
    ScreenCaptureManager *scm = [ScreenCaptureManager sharedManager];
    SettingsManager *sm = [SettingsManager sharedManager];
    
    if (sm.autoSaveOnCopy) {
        NSString *path = [sm generateNewFilePathWithExtension];
        [scm saveImage:screenshot toPath:path format:sm.imageFormat];
    }
    [scm copyImageToClipboard:screenshot];
}

#pragma mark - CaptureOverlayDelegate

- (void)captureOverlayDidCancel:(CaptureOverlayView *)overlay {
    if (_activeOverlayWindow) {
        [_activeOverlayWindow orderOut:nil];
        _activeOverlayWindow = nil;
    }
}

- (void)captureOverlay:(CaptureOverlayView *)overlay didFinishWithImage:(NSImage *)image shouldSaveToFile:(BOOL)save {
    if (_activeOverlayWindow) {
        [_activeOverlayWindow orderOut:nil];
        _activeOverlayWindow = nil;
    }
    
    if (!image) return;
    
    ScreenCaptureManager *scm = [ScreenCaptureManager sharedManager];
    SettingsManager *sm = [SettingsManager sharedManager];
    
    if (save) {
        NSString *targetPath = [sm generateNewFilePathWithExtension];
        [scm saveImage:image toPath:targetPath format:sm.imageFormat];
    } else {
        [scm copyImageToClipboard:image];
    }
}

- (void)captureOverlay:(CaptureOverlayView *)overlay didRequestRecordRect:(NSRect)rect {
    NSScreen *targetScreen = _activeCaptureScreen ?: [self screenUnderMouse];
    if (_activeOverlayWindow) {
        [_activeOverlayWindow orderOut:nil];
        _activeOverlayWindow = nil;
    }
    _activeCaptureScreen = nil;
    
    [[ScreenRecorderManager sharedManager] startRecordingScreen:targetScreen cropRect:rect];
    [self buildStatusMenu];
}

#pragma mark - Menu Actions

- (void)openSaveFolder {
    NSString *path = [[SettingsManager sharedManager] ensureSaveDirectoryExists];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)openSettings {
    [[SettingsWindowController sharedController] showSettingsWindow];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end
