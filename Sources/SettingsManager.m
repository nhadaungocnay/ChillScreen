#import "SettingsManager.h"

NSString * const kSettingsChangedNotification = @"ChillScreenSettingsChangedNotification";

static NSString * const kPrefHotkeyKey = @"ChillScreen_HotkeyKey";
static NSString * const kPrefHotkeyModifiers = @"ChillScreen_HotkeyModifiers";
static NSString * const kPrefSavePath = @"ChillScreen_SavePath";
static NSString * const kPrefImageFormat = @"ChillScreen_ImageFormat";
static NSString * const kPrefPlaySound = @"ChillScreen_PlaySound";
static NSString * const kPrefAutoSave = @"ChillScreen_AutoSave";
static NSString * const kPrefShowMagnifier = @"ChillScreen_ShowMagnifier";

@implementation SettingsManager

+ (instancetype)sharedManager {
    static SettingsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[SettingsManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Default hotkey: Cmd + Shift + A (kVK_ANSI_A = 0, cmdKey | shiftKey = 0x0100 | 0x0200)
    if ([defaults objectForKey:kPrefHotkeyKey]) {
        _hotkeyKey = (UInt32)[defaults integerForKey:kPrefHotkeyKey];
    } else {
        _hotkeyKey = kVK_ANSI_A; // 0
    }
    
    if ([defaults objectForKey:kPrefHotkeyModifiers]) {
        _hotkeyModifiers = (UInt32)[defaults integerForKey:kPrefHotkeyModifiers];
    } else {
        _hotkeyModifiers = (cmdKey | shiftKey); // 0x0300
    }
    
    NSString *savedPath = [defaults stringForKey:kPrefSavePath];
    if (savedPath && savedPath.length > 0) {
        _saveFolderPath = savedPath;
    } else {
        NSString *picturesDir = [NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES) firstObject];
        _saveFolderPath = [picturesDir stringByAppendingPathComponent:@"ChillScreen"];
    }
    
    _imageFormat = [defaults stringForKey:kPrefImageFormat] ?: @"PNG";
    _playSound = [defaults objectForKey:kPrefPlaySound] ? [defaults boolForKey:kPrefPlaySound] : YES;
    _autoSaveOnCopy = [defaults boolForKey:kPrefAutoSave];
    _showMagnifier = [defaults objectForKey:kPrefShowMagnifier] ? [defaults boolForKey:kPrefShowMagnifier] : YES;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:_hotkeyKey forKey:kPrefHotkeyKey];
    [defaults setInteger:_hotkeyModifiers forKey:kPrefHotkeyModifiers];
    [defaults setObject:_saveFolderPath forKey:kPrefSavePath];
    [defaults setObject:_imageFormat forKey:kPrefImageFormat];
    [defaults setBool:_playSound forKey:kPrefPlaySound];
    [defaults setBool:_autoSaveOnCopy forKey:kPrefAutoSave];
    [defaults setBool:_showMagnifier forKey:kPrefShowMagnifier];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsChangedNotification object:self];
}

- (void)resetToDefaults {
    _hotkeyKey = kVK_ANSI_A;
    _hotkeyModifiers = (cmdKey | shiftKey);
    NSString *picturesDir = [NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES) firstObject];
    _saveFolderPath = [picturesDir stringByAppendingPathComponent:@"ChillScreen"];
    _imageFormat = @"PNG";
    _playSound = YES;
    _autoSaveOnCopy = NO;
    _showMagnifier = YES;
    [self saveSettings];
}

- (NSString *)formattedHotkeyString {
    NSString *modStr = [SettingsManager stringForCarbonModifiers:_hotkeyModifiers];
    NSString *keyStr = [SettingsManager stringForKeyCode:_hotkeyKey];
    return [NSString stringWithFormat:@"%@ %@", modStr, keyStr];
}

- (NSString *)ensureSaveDirectoryExists {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *folder = [_saveFolderPath stringByExpandingTildeInPath];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:folder isDirectory:&isDir]) {
        [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return folder;
}

- (NSString *)generateNewFilePathWithExtension {
    NSString *folder = [self ensureSaveDirectoryExists];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH.mm.ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *ext = [_imageFormat.uppercaseString isEqualToString:@"JPG"] ? @"jpg" : @"png";
    NSString *filename = [NSString stringWithFormat:@"ChillScreen_%@.%@", timestamp, ext];
    return [folder stringByAppendingPathComponent:filename];
}

+ (NSString *)stringForCarbonModifiers:(UInt32)modifiers {
    NSMutableArray *parts = [NSMutableArray array];
    if (modifiers & controlKey) {
        [parts addObject:@"⌃"];
    }
    if (modifiers & optionKey) {
        [parts addObject:@"⌥"];
    }
    if (modifiers & shiftKey) {
        [parts addObject:@"⇧"];
    }
    if (modifiers & cmdKey) {
        [parts addObject:@"⌘"];
    }
    return [parts componentsJoinedByString:@" "];
}

+ (NSString *)stringForKeyCode:(UInt32)keyCode {
    switch (keyCode) {
        case kVK_ANSI_A: return @"A";
        case kVK_ANSI_B: return @"B";
        case kVK_ANSI_C: return @"C";
        case kVK_ANSI_D: return @"D";
        case kVK_ANSI_E: return @"E";
        case kVK_ANSI_F: return @"F";
        case kVK_ANSI_G: return @"G";
        case kVK_ANSI_H: return @"H";
        case kVK_ANSI_I: return @"I";
        case kVK_ANSI_J: return @"J";
        case kVK_ANSI_K: return @"K";
        case kVK_ANSI_L: return @"L";
        case kVK_ANSI_M: return @"M";
        case kVK_ANSI_N: return @"N";
        case kVK_ANSI_O: return @"O";
        case kVK_ANSI_P: return @"P";
        case kVK_ANSI_Q: return @"Q";
        case kVK_ANSI_R: return @"R";
        case kVK_ANSI_S: return @"S";
        case kVK_ANSI_T: return @"T";
        case kVK_ANSI_U: return @"U";
        case kVK_ANSI_V: return @"V";
        case kVK_ANSI_W: return @"W";
        case kVK_ANSI_X: return @"X";
        case kVK_ANSI_Y: return @"Y";
        case kVK_ANSI_Z: return @"Z";
        case kVK_ANSI_0: return @"0";
        case kVK_ANSI_1: return @"1";
        case kVK_ANSI_2: return @"2";
        case kVK_ANSI_3: return @"3";
        case kVK_ANSI_4: return @"4";
        case kVK_ANSI_5: return @"5";
        case kVK_ANSI_6: return @"6";
        case kVK_ANSI_7: return @"7";
        case kVK_ANSI_8: return @"8";
        case kVK_ANSI_9: return @"9";
        case kVK_Space: return @"Space";
        case kVK_Return: return @"Return";
        case kVK_Tab: return @"Tab";
        case kVK_F1: return @"F1";
        case kVK_F2: return @"F2";
        case kVK_F3: return @"F3";
        case kVK_F4: return @"F4";
        case kVK_F5: return @"F5";
        case kVK_F6: return @"F6";
        case kVK_F7: return @"F7";
        case kVK_F8: return @"F8";
        case kVK_F9: return @"F9";
        case kVK_F10: return @"F10";
        case kVK_F11: return @"F11";
        case kVK_F12: return @"F12";
        default: return [NSString stringWithFormat:@"Key(0x%02X)", keyCode];
    }
}

@end
