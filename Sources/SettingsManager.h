#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kSettingsChangedNotification;

@interface SettingsManager : NSObject

@property (nonatomic, assign) UInt32 hotkeyKey;
@property (nonatomic, assign) UInt32 hotkeyModifiers;
@property (nonatomic, assign) UInt32 recordHotkeyKey;
@property (nonatomic, assign) UInt32 recordHotkeyModifiers;
@property (nonatomic, copy) NSString *saveFolderPath;
@property (nonatomic, copy) NSString *imageFormat; // @"PNG" or @"JPG"
@property (nonatomic, assign) BOOL playSound;
@property (nonatomic, assign) BOOL autoSaveOnCopy;
@property (nonatomic, assign) BOOL showMagnifier;

// Video recording settings
@property (nonatomic, copy) NSString *videoFormat;  // @"MP4" or @"MOV"
@property (nonatomic, copy) NSString *videoCodec;   // @"HEVC" or @"H264"
@property (nonatomic, assign) NSInteger videoFPS;   // 30 or 60
@property (nonatomic, copy) NSString *videoQuality; // @"LIGHT" or @"HIGH"
@property (nonatomic, assign) BOOL recordAudio;
@property (nonatomic, assign) BOOL showMouseClicks;

+ (instancetype)sharedManager;

- (void)loadSettings;
- (void)saveSettings;
- (void)resetToDefaults;

- (NSString *)formattedHotkeyString;
- (NSString *)formattedRecordHotkeyString;
- (NSString *)ensureSaveDirectoryExists;
- (NSString *)generateNewFilePathWithExtension;
- (NSString *)generateNewVideoFilePath;

// Carbon modifiers helpers
+ (NSString *)stringForCarbonModifiers:(UInt32)modifiers;
+ (NSString *)stringForKeyCode:(UInt32)keyCode;

@end

NS_ASSUME_NONNULL_END
