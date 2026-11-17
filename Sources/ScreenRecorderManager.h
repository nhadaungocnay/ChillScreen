#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenRecorderManager : NSObject

@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) NSTimeInterval elapsedSeconds;
@property (nonatomic, copy, nullable) void (^onRecordingTimerTick)(NSString *formattedTime);
@property (nonatomic, copy, nullable) void (^onRecordingFinished)(NSString * _Nullable outputPath, NSError * _Nullable error);

+ (instancetype)sharedManager;

- (void)startRecordingScreen:(nullable NSScreen *)screen cropRect:(NSRect)cropRect;
- (void)stopRecording;

@end

NS_ASSUME_NONNULL_END
