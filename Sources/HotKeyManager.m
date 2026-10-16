#import "HotKeyManager.h"
#import "SettingsManager.h"

static const OSType kChillScreenHotKeySignature = 'CHIL';
static const UInt32 kChillScreenHotKeyID = 1;

static OSStatus CarbonHotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    EventHotKeyID hkID;
    GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkID), NULL, &hkID);
    if (hkID.signature == kChillScreenHotKeySignature && hkID.id == kChillScreenHotKeyID) {
        dispatch_async(dispatch_get_main_queue(), ^{
            HotKeyManager *manager = [HotKeyManager sharedManager];
            if (manager.onHotKeyPressed) {
                manager.onHotKeyPressed();
            }
        });
    }
    return noErr;
}

@interface HotKeyManager () {
    EventHandlerRef _eventHandlerRef;
    EventHotKeyRef _hotKeyRef;
}
@end

@implementation HotKeyManager

+ (instancetype)sharedManager {
    static HotKeyManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HotKeyManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSettingsChanged:)
                                                     name:kSettingsChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopListening];
}

- (void)handleSettingsChanged:(NSNotification *)note {
    [self updateFromSettings];
}

- (void)startListening {
    if (!_eventHandlerRef) {
        EventTypeSpec eventType;
        eventType.eventClass = kEventClassKeyboard;
        eventType.eventKind = kEventHotKeyPressed;
        InstallApplicationEventHandler(&CarbonHotKeyHandler, 1, &eventType, NULL, &_eventHandlerRef);
    }
    [self updateFromSettings];
}

- (void)stopListening {
    if (_hotKeyRef) {
        UnregisterEventHotKey(_hotKeyRef);
        _hotKeyRef = NULL;
    }
    if (_eventHandlerRef) {
        RemoveEventHandler(_eventHandlerRef);
        _eventHandlerRef = NULL;
    }
}

- (void)updateFromSettings {
    if (_hotKeyRef) {
        UnregisterEventHotKey(_hotKeyRef);
        _hotKeyRef = NULL;
    }
    
    SettingsManager *sm = [SettingsManager sharedManager];
    EventHotKeyID hotKeyID;
    hotKeyID.signature = kChillScreenHotKeySignature;
    hotKeyID.id = kChillScreenHotKeyID;
    
    OSStatus status = RegisterEventHotKey(sm.hotkeyKey,
                                         sm.hotkeyModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &_hotKeyRef);
    if (status != noErr) {
        NSLog(@"[ChillScreen] Failed to register global hotkey (status: %d)", (int)status);
    } else {
        NSLog(@"[ChillScreen] Successfully registered global hotkey: %@", [sm formattedHotkeyString]);
    }
}

@end
