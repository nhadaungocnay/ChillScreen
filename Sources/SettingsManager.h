#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kSettingsChangedNotification;

@interface SettingsManager : NSObject

@property (nonatomic, assign) UInt32 hotkeyKey;
@property (nonatomic, assign) UInt32 hotkeyModifiers;
@property (nonatomic, copy) NSString *saveFolderPath;
@property (nonatomic, copy) NSString *imageFormat; // @"PNG" or @"JPG"
@property (nonatomic, assign) BOOL playSound;
@property (nonatomic, assign) BOOL autoSaveOnCopy;
@property (nonatomic, assign) BOOL showMagnifier;

+ (instancetype)sharedManager;

- (void)loadSettings;
- (void)saveSettings;
- (void)resetToDefaults;

- (NSString *)formattedHotkeyString;
- (NSString *)ensureSaveDirectoryExists;
- (NSString *)generateNewFilePathWithExtension;

// Carbon modifiers helpers
+ (NSString *)stringForCarbonModifiers:(UInt32)modifiers;
+ (NSString *)stringForKeyCode:(UInt32)keyCode;

@end

NS_ASSUME_NONNULL_END
