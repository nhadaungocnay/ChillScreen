#import "SettingsWindowController.h"
#import "HotKeyRecorderView.h"
#import "../SettingsManager.h"
#import "../ScreenCaptureManager.h"

@interface SettingsWindowController () <HotKeyRecorderDelegate>

@property (nonatomic, strong) HotKeyRecorderView *recorderView;
@property (nonatomic, strong) HotKeyRecorderView *recordHotkeyRecorderView;
@property (nonatomic, strong) NSTextField *savePathField;
@property (nonatomic, strong) NSSegmentedControl *formatControl;
@property (nonatomic, strong) NSButton *soundCheckbox;
@property (nonatomic, strong) NSButton *autoSaveCheckbox;
@property (nonatomic, strong) NSButton *magnifierCheckbox;

// Video settings controls
@property (nonatomic, strong) NSSegmentedControl *videoFormatControl;
@property (nonatomic, strong) NSSegmentedControl *videoCodecControl;
@property (nonatomic, strong) NSSegmentedControl *videoFPSControl;
@property (nonatomic, strong) NSSegmentedControl *videoQualityControl;
@property (nonatomic, strong) NSButton *recordAudioCheckbox;
@property (nonatomic, strong) NSButton *showClicksCheckbox;

@property (nonatomic, strong) NSTextField *permissionStatusLabel;

@end

@implementation SettingsWindowController

+ (instancetype)sharedController {
    static SettingsWindowController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SettingsWindowController alloc] init];
    });
    return shared;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 520, 680);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Cài đặt ChillScreen";
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;
    
    CGFloat width = 520;
    CGFloat y = 635;
    SettingsManager *sm = [SettingsManager sharedManager];
    
    // --- SECTION 1: HOTKEYS ---
    NSTextField *sec1 = [self createSectionHeader:@"Phím tắt nhanh (Global Hotkeys)" y:y];
    [content addSubview:sec1];
    y -= 28;
    
    NSTextField *hkDesc = [self createLabel:@"Chụp ảnh màn hình:" x:30 y:y width:150];
    [content addSubview:hkDesc];
    
    _recorderView = [[HotKeyRecorderView alloc] initWithFrame:NSMakeRect(185, y - 5, 145, 30)];
    _recorderView.delegate = self;
    [_recorderView setKeyCode:sm.hotkeyKey modifiers:sm.hotkeyModifiers];
    [content addSubview:_recorderView];
    
    NSButton *resetHkBtn = [[NSButton alloc] initWithFrame:NSMakeRect(340, y - 5, 150, 30)];
    resetHkBtn.title = @"Mặc định (⇧⌘A)";
    resetHkBtn.bezelStyle = NSBezelStyleRounded;
    resetHkBtn.target = self;
    resetHkBtn.action = @selector(resetHotkeyClicked:);
    [content addSubview:resetHkBtn];
    y -= 38;
    
    NSTextField *recHkDesc = [self createLabel:@"Quay video màn hình:" x:30 y:y width:150];
    [content addSubview:recHkDesc];
    
    _recordHotkeyRecorderView = [[HotKeyRecorderView alloc] initWithFrame:NSMakeRect(185, y - 5, 145, 30)];
    _recordHotkeyRecorderView.delegate = self;
    [_recordHotkeyRecorderView setKeyCode:sm.recordHotkeyKey modifiers:sm.recordHotkeyModifiers];
    [content addSubview:_recordHotkeyRecorderView];
    
    NSButton *resetRecHkBtn = [[NSButton alloc] initWithFrame:NSMakeRect(340, y - 5, 150, 30)];
    resetRecHkBtn.title = @"Mặc định (⇧⌘R)";
    resetRecHkBtn.bezelStyle = NSBezelStyleRounded;
    resetRecHkBtn.target = self;
    resetRecHkBtn.action = @selector(resetRecordHotkeyClicked:);
    [content addSubview:resetRecHkBtn];
    y -= 24;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 24;
    
    // --- SECTION 2: STORAGE PATH ---
    NSTextField *sec2 = [self createSectionHeader:@"Thư mục lưu Ảnh & Video (Save Folder)" y:y];
    [content addSubview:sec2];
    y -= 34;
    
    _savePathField = [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 340, 26)];
    _savePathField.editable = NO;
    _savePathField.selectable = YES;
    _savePathField.stringValue = sm.saveFolderPath;
    _savePathField.font = [NSFont systemFontOfSize:12];
    [content addSubview:_savePathField];
    
    NSButton *browseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(380, y - 2, 110, 30)];
    browseBtn.title = @"Chọn thư mục...";
    browseBtn.bezelStyle = NSBezelStyleRounded;
    browseBtn.target = self;
    browseBtn.action = @selector(browseFolderClicked:);
    [content addSubview:browseBtn];
    y -= 32;
    
    NSButton *openFinderBtn = [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 140, 24)];
    openFinderBtn.title = @"Mở trong Finder";
    openFinderBtn.bezelStyle = NSBezelStyleInline;
    openFinderBtn.target = self;
    openFinderBtn.action = @selector(openInFinderClicked:);
    [content addSubview:openFinderBtn];
    y -= 18;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 24;
    
    // --- SECTION 3: IMAGE OPTIONS ---
    NSTextField *sec3 = [self createSectionHeader:@"Tuỳ chọn Chụp Ảnh" y:y];
    [content addSubview:sec3];
    y -= 30;
    
    NSTextField *fmtLabel = [self createLabel:@"Định dạng ảnh:" x:30 y:y width:105];
    [content addSubview:fmtLabel];
    
    _formatControl = [NSSegmentedControl segmentedControlWithLabels:@[@"PNG (Nét nhất)", @"JPG (Nhẹ hơn)"]
                                                       trackingMode:NSSegmentSwitchTrackingSelectOne
                                                             target:self
                                                             action:@selector(formatChanged:)];
    _formatControl.frame = NSMakeRect(145, y - 4, 230, 26);
    _formatControl.selectedSegment = [sm.imageFormat.uppercaseString isEqualToString:@"JPG"] ? 1 : 0;
    [content addSubview:_formatControl];
    y -= 28;
    
    _soundCheckbox = [self createCheckbox:@"Phát âm thanh màn trập (Shutter Sound) khi chụp / xong video" checked:sm.playSound y:y];
    _soundCheckbox.action = @selector(soundCheckboxChanged:);
    [content addSubview:_soundCheckbox];
    y -= 24;
    
    _autoSaveCheckbox = [self createCheckbox:@"Tự động lưu ảnh vào thư mục khi bấm Copy (Enter)" checked:sm.autoSaveOnCopy y:y];
    _autoSaveCheckbox.action = @selector(autoSaveCheckboxChanged:);
    [content addSubview:_autoSaveCheckbox];
    y -= 24;
    
    _magnifierCheckbox = [self createCheckbox:@"Hiện kính lúp phóng to khi chọn vùng" checked:sm.showMagnifier y:y];
    _magnifierCheckbox.action = @selector(magnifierCheckboxChanged:);
    [content addSubview:_magnifierCheckbox];
    y -= 18;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 24;
    
    // --- SECTION 4: VIDEO RECORDING OPTIONS ---
    NSTextField *sec4 = [self createSectionHeader:@"Quay Video Màn Hình (Tối ưu Dung lượng & Độ nét)" y:y];
    [content addSubview:sec4];
    y -= 30;
    
    NSTextField *vFmtLabel = [self createLabel:@"Định dạng file:" x:30 y:y width:105];
    [content addSubview:vFmtLabel];
    _videoFormatControl = [NSSegmentedControl segmentedControlWithLabels:@[@"MP4 (Phổ biến)", @"MOV (QuickTime)"]
                                                            trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                  target:self
                                                                  action:@selector(videoFormatChanged:)];
    _videoFormatControl.frame = NSMakeRect(145, y - 4, 240, 26);
    _videoFormatControl.selectedSegment = [sm.videoFormat.uppercaseString isEqualToString:@"MOV"] ? 1 : 0;
    [content addSubview:_videoFormatControl];
    y -= 32;
    
    NSTextField *vCodecLabel = [self createLabel:@"Chuẩn nén:" x:30 y:y width:105];
    [content addSubview:vCodecLabel];
    _videoCodecControl = [NSSegmentedControl segmentedControlWithLabels:@[@"HEVC / H.265 (Siêu nhẹ)", @"H.264 (Tương thích)"]
                                                             trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                   target:self
                                                                   action:@selector(videoCodecChanged:)];
    _videoCodecControl.frame = NSMakeRect(145, y - 4, 320, 26);
    _videoCodecControl.selectedSegment = [sm.videoCodec.uppercaseString isEqualToString:@"H264"] ? 1 : 0;
    [content addSubview:_videoCodecControl];
    y -= 32;
    
    NSTextField *vFpsLabel = [self createLabel:@"Tốc độ FPS:" x:30 y:y width:105];
    [content addSubview:vFpsLabel];
    _videoFPSControl = [NSSegmentedControl segmentedControlWithLabels:@[@"30 FPS (Nhẹ)", @"60 FPS (Mượt)"]
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(videoFPSChanged:)];
    _videoFPSControl.frame = NSMakeRect(145, y - 4, 240, 26);
    _videoFPSControl.selectedSegment = (sm.videoFPS == 60) ? 1 : 0;
    [content addSubview:_videoFPSControl];
    y -= 32;
    
    NSTextField *vQualLabel = [self createLabel:@"Độ phân giải:" x:30 y:y width:105];
    [content addSubview:vQualLabel];
    _videoQualityControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Tối ưu dung lượng (Nhẹ)", @"Retina (Siêu nét)"]
                                                               trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                     target:self
                                                                     action:@selector(videoQualityChanged:)];
    _videoQualityControl.frame = NSMakeRect(145, y - 4, 320, 26);
    _videoQualityControl.selectedSegment = [sm.videoQuality.uppercaseString isEqualToString:@"HIGH"] ? 1 : 0;
    [content addSubview:_videoQualityControl];
    y -= 28;
    
    _recordAudioCheckbox = [self createCheckbox:@"Thu âm Microphone khi quay video" checked:sm.recordAudio y:y];
    _recordAudioCheckbox.action = @selector(recordAudioChanged:);
    [content addSubview:_recordAudioCheckbox];
    y -= 24;
    
    _showClicksCheckbox = [self createCheckbox:@"Hiển thị hiệu ứng click chuột (chế độ dự phòng)" checked:sm.showMouseClicks y:y];
    _showClicksCheckbox.action = @selector(showClicksChanged:);
    [content addSubview:_showClicksCheckbox];
    y -= 18;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 24;
    
    // --- SECTION 5: PERMISSIONS ---
    NSTextField *sec5 = [self createSectionHeader:@"Quyền riêng tư (Screen Recording)" y:y];
    [content addSubview:sec5];
    y -= 28;
    
    BOOL hasPerm = [[ScreenCaptureManager sharedManager] hasScreenCapturePermission];
    NSString *permText = hasPerm ? @"✓ Đã cấp quyền chụp & quay màn hình" : @"⚠️ Chưa cấp quyền chụp & quay màn hình";
    NSColor *permColor = hasPerm ? [NSColor systemGreenColor] : [NSColor systemOrangeColor];
    
    _permissionStatusLabel = [self createLabel:permText x:30 y:y width:290];
    _permissionStatusLabel.textColor = permColor;
    _permissionStatusLabel.font = [NSFont boldSystemFontOfSize:12];
    [content addSubview:_permissionStatusLabel];
    
    NSButton *permBtn = [[NSButton alloc] initWithFrame:NSMakeRect(340, y - 4, 150, 28)];
    permBtn.title = @"Cài đặt hệ thống...";
    permBtn.bezelStyle = NSBezelStyleRounded;
    permBtn.target = self;
    permBtn.action = @selector(openPreferencesClicked:);
    [content addSubview:permBtn];
}

- (NSTextField *)createSectionHeader:(NSString *)title y:(CGFloat)y {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 440, 22)];
    label.stringValue = title;
    label.font = [NSFont boldSystemFontOfSize:13];
    label.textColor = [NSColor labelColor];
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

- (NSTextField *)createLabel:(NSString *)text x:(CGFloat)x y:(CGFloat)y width:(CGFloat)w {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, w, 20)];
    label.stringValue = text;
    label.font = [NSFont systemFontOfSize:12];
    label.textColor = [NSColor secondaryLabelColor];
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    return label;
}

- (NSButton *)createCheckbox:(NSString *)title checked:(BOOL)checked y:(CGFloat)y {
    NSButton *cb = [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 420, 20)];
    cb.buttonType = NSButtonTypeSwitch;
    cb.title = title;
    cb.font = [NSFont systemFontOfSize:12];
    cb.state = checked ? NSControlStateValueOn : NSControlStateValueOff;
    cb.target = self;
    return cb;
}

- (NSBox *)createHorizontalLineY:(CGFloat)y width:(CGFloat)w {
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(30, y, w - 60, 1)];
    line.boxType = NSBoxSeparator;
    return line;
}

- (void)showSettingsWindow {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - HotKeyRecorderDelegate

- (void)hotKeyRecorderDidRecordKey:(UInt32)keyCode modifiers:(UInt32)carbonModifiers {
    SettingsManager *sm = [SettingsManager sharedManager];
    if (self.window.firstResponder == _recordHotkeyRecorderView) {
        sm.recordHotkeyKey = keyCode;
        sm.recordHotkeyModifiers = carbonModifiers;
    } else {
        sm.hotkeyKey = keyCode;
        sm.hotkeyModifiers = carbonModifiers;
    }
    [sm saveSettings];
}

- (void)resetHotkeyClicked:(id)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.hotkeyKey = kVK_ANSI_A;
    sm.hotkeyModifiers = (cmdKey | shiftKey);
    [sm saveSettings];
    [_recorderView setKeyCode:sm.hotkeyKey modifiers:sm.hotkeyModifiers];
}

- (void)resetRecordHotkeyClicked:(id)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.recordHotkeyKey = kVK_ANSI_R;
    sm.recordHotkeyModifiers = (cmdKey | shiftKey);
    [sm saveSettings];
    [_recordHotkeyRecorderView setKeyCode:sm.recordHotkeyKey modifiers:sm.recordHotkeyModifiers];
}

#pragma mark - Storage Actions

- (void)browseFolderClicked:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.prompt = @"Chọn thư mục";
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *selectedUrl = panel.URL;
            if (selectedUrl) {
                NSString *path = selectedUrl.path;
                SettingsManager *sm = [SettingsManager sharedManager];
                sm.saveFolderPath = path;
                [sm saveSettings];
                self->_savePathField.stringValue = path;
            }
        }
    }];
}

- (void)openInFinderClicked:(id)sender {
    NSString *path = [[SettingsManager sharedManager] ensureSaveDirectoryExists];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

#pragma mark - Options Actions

- (void)formatChanged:(NSSegmentedControl *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.imageFormat = (sender.selectedSegment == 1) ? @"JPG" : @"PNG";
    [sm saveSettings];
}

- (void)soundCheckboxChanged:(NSButton *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.playSound = (sender.state == NSControlStateValueOn);
    [sm saveSettings];
}

- (void)autoSaveCheckboxChanged:(NSButton *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.autoSaveOnCopy = (sender.state == NSControlStateValueOn);
    [sm saveSettings];
}

- (void)magnifierCheckboxChanged:(NSButton *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.showMagnifier = (sender.state == NSControlStateValueOn);
    [sm saveSettings];
}

- (void)videoFormatChanged:(NSSegmentedControl *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.videoFormat = (sender.selectedSegment == 1) ? @"MOV" : @"MP4";
    [sm saveSettings];
}

- (void)videoCodecChanged:(NSSegmentedControl *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.videoCodec = (sender.selectedSegment == 1) ? @"H264" : @"HEVC";
    [sm saveSettings];
}

- (void)videoFPSChanged:(NSSegmentedControl *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.videoFPS = (sender.selectedSegment == 1) ? 60 : 30;
    [sm saveSettings];
}

- (void)videoQualityChanged:(NSSegmentedControl *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.videoQuality = (sender.selectedSegment == 1) ? @"HIGH" : @"LIGHT";
    [sm saveSettings];
}

- (void)recordAudioChanged:(NSButton *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.recordAudio = (sender.state == NSControlStateValueOn);
    [sm saveSettings];
}

- (void)showClicksChanged:(NSButton *)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.showMouseClicks = (sender.state == NSControlStateValueOn);
    [sm saveSettings];
}

- (void)openPreferencesClicked:(id)sender {
    [[ScreenCaptureManager sharedManager] openScreenCapturePreferences];
}

@end
