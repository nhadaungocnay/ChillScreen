#import "SettingsWindowController.h"
#import "HotKeyRecorderView.h"
#import "../SettingsManager.h"
#import "../ScreenCaptureManager.h"

@interface SettingsWindowController () <HotKeyRecorderDelegate>

@property (nonatomic, strong) HotKeyRecorderView *recorderView;
@property (nonatomic, strong) NSTextField *savePathField;
@property (nonatomic, strong) NSSegmentedControl *formatControl;
@property (nonatomic, strong) NSButton *soundCheckbox;
@property (nonatomic, strong) NSButton *autoSaveCheckbox;
@property (nonatomic, strong) NSButton *magnifierCheckbox;
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
    NSRect frame = NSMakeRect(0, 0, 500, 480);
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
    
    CGFloat width = 500;
    CGFloat y = 430;
    
    // --- SECTION 1: HOTKEY ---
    NSTextField *sec1 = [self createSectionHeader:@"Phím tắt chụp nhanh (Global Hotkey)" y:y];
    [content addSubview:sec1];
    y -= 42;
    
    NSTextField *hkDesc = [self createLabel:@"Nhấp vào ô bên dưới rồi bấm tổ hợp phím:" x:30 y:y width:300];
    [content addSubview:hkDesc];
    y -= 34;
    
    _recorderView = [[HotKeyRecorderView alloc] initWithFrame:NSMakeRect(30, y, 160, 32)];
    _recorderView.delegate = self;
    SettingsManager *sm = [SettingsManager sharedManager];
    [_recorderView setKeyCode:sm.hotkeyKey modifiers:sm.hotkeyModifiers];
    [content addSubview:_recorderView];
    
    NSButton *resetHkBtn = [[NSButton alloc] initWithFrame:NSMakeRect(205, y, 130, 32)];
    resetHkBtn.title = @"Về mặc định (⇧⌘A)";
    resetHkBtn.bezelStyle = NSBezelStyleRounded;
    resetHkBtn.target = self;
    resetHkBtn.action = @selector(resetHotkeyClicked:);
    [content addSubview:resetHkBtn];
    y -= 45;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 25;
    
    // --- SECTION 2: STORAGE PATH ---
    NSTextField *sec2 = [self createSectionHeader:@"Thư mục lưu ảnh (Save Folder)" y:y];
    [content addSubview:sec2];
    y -= 38;
    
    _savePathField = [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 320, 26)];
    _savePathField.editable = NO;
    _savePathField.selectable = YES;
    _savePathField.stringValue = sm.saveFolderPath;
    _savePathField.font = [NSFont systemFontOfSize:12];
    [content addSubview:_savePathField];
    
    NSButton *browseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(358, y - 2, 110, 30)];
    browseBtn.title = @"Chọn thư mục...";
    browseBtn.bezelStyle = NSBezelStyleRounded;
    browseBtn.target = self;
    browseBtn.action = @selector(browseFolderClicked:);
    [content addSubview:browseBtn];
    y -= 34;
    
    NSButton *openFinderBtn = [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 140, 26)];
    openFinderBtn.title = @"Mở trong Finder";
    openFinderBtn.bezelStyle = NSBezelStyleInline;
    openFinderBtn.target = self;
    openFinderBtn.action = @selector(openInFinderClicked:);
    [content addSubview:openFinderBtn];
    y -= 40;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 25;
    
    // --- SECTION 3: OPTIONS & FORMAT ---
    NSTextField *sec3 = [self createSectionHeader:@"Tuỳ chọn chụp & Xuất ảnh" y:y];
    [content addSubview:sec3];
    y -= 34;
    
    NSTextField *fmtLabel = [self createLabel:@"Định dạng file:" x:30 y:y width:100];
    [content addSubview:fmtLabel];
    
    _formatControl = [NSSegmentedControl segmentedControlWithLabels:@[@"PNG (Nét nhất)", @"JPG (Nhẹ hơn)"]
                                                       trackingMode:NSSegmentSwitchTrackingSelectOne
                                                             target:self
                                                             action:@selector(formatChanged:)];
    _formatControl.frame = NSMakeRect(140, y - 4, 220, 28);
    _formatControl.selectedSegment = [sm.imageFormat.uppercaseString isEqualToString:@"JPG"] ? 1 : 0;
    [content addSubview:_formatControl];
    y -= 32;
    
    _soundCheckbox = [self createCheckbox:@"Phát âm thanh màn trập (Shutter Sound) khi chụp" checked:sm.playSound y:y];
    _soundCheckbox.action = @selector(soundCheckboxChanged:);
    [content addSubview:_soundCheckbox];
    y -= 26;
    
    _autoSaveCheckbox = [self createCheckbox:@"Tự động lưu vào thư mục khi bấm Copy (Enter)" checked:sm.autoSaveOnCopy y:y];
    _autoSaveCheckbox.action = @selector(autoSaveCheckboxChanged:);
    [content addSubview:_autoSaveCheckbox];
    y -= 26;
    
    _magnifierCheckbox = [self createCheckbox:@"Hiện kính lúp phóng to khi chọn vùng" checked:sm.showMagnifier y:y];
    _magnifierCheckbox.action = @selector(magnifierCheckboxChanged:);
    [content addSubview:_magnifierCheckbox];
    y -= 35;
    
    // Divider
    [content addSubview:[self createHorizontalLineY:y width:width]];
    y -= 25;
    
    // --- SECTION 4: PERMISSIONS ---
    NSTextField *sec4 = [self createSectionHeader:@"Quyền riêng tư (Screen Recording)" y:y];
    [content addSubview:sec4];
    y -= 30;
    
    BOOL hasPerm = [[ScreenCaptureManager sharedManager] hasScreenCapturePermission];
    NSString *permText = hasPerm ? @"✓ Đã cấp quyền chụp màn hình" : @"⚠️ Chưa cấp quyền chụp màn hình";
    NSColor *permColor = hasPerm ? [NSColor systemGreenColor] : [NSColor systemOrangeColor];
    
    _permissionStatusLabel = [self createLabel:permText x:30 y:y width:280];
    _permissionStatusLabel.textColor = permColor;
    _permissionStatusLabel.font = [NSFont boldSystemFontOfSize:12];
    [content addSubview:_permissionStatusLabel];
    
    NSButton *permBtn = [[NSButton alloc] initWithFrame:NSMakeRect(320, y - 4, 150, 28)];
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
    sm.hotkeyKey = keyCode;
    sm.hotkeyModifiers = carbonModifiers;
    [sm saveSettings];
}

- (void)resetHotkeyClicked:(id)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.hotkeyKey = kVK_ANSI_A;
    sm.hotkeyModifiers = (cmdKey | shiftKey);
    [sm saveSettings];
    [_recorderView setKeyCode:sm.hotkeyKey modifiers:sm.hotkeyModifiers];
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

- (void)openPreferencesClicked:(id)sender {
    [[ScreenCaptureManager sharedManager] openScreenCapturePreferences];
}

@end
