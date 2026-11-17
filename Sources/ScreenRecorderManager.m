#import "ScreenRecorderManager.h"
#import "ScreenCaptureManager.h"
#import "SettingsManager.h"
#import "UI/RecordingOverlayWindow.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <VideoToolbox/VideoToolbox.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

API_AVAILABLE(macos(12.3))
@interface ScreenRecorderStreamDelegate : NSObject <SCStreamOutput, SCStreamDelegate>
@property (nonatomic, copy) void (^onVideoSample)(CMSampleBufferRef sampleBuffer);
@property (nonatomic, copy) void (^onStreamError)(NSError *error);
@end

@implementation ScreenRecorderStreamDelegate

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type == SCStreamOutputTypeScreen && self.onVideoSample) {
        self.onVideoSample(sampleBuffer);
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    if (error && self.onStreamError) {
        self.onStreamError(error);
    }
}

@end

@interface ScreenRecorderManager () <AVCaptureAudioDataOutputSampleBufferDelegate> {
    BOOL _isRecording;
    BOOL _isStopping;
    BOOL _sessionStarted;
    dispatch_queue_t _writerQueue;
    dispatch_queue_t _audioQueue;
    
    NSTimer *_uiTimer;
    NSDate *_startDate;
}

@property (nonatomic, strong, nullable) RecordingOverlayWindow *overlayWindow;
@property (nonatomic, copy, nullable) NSString *currentOutputPath;
@property (nonatomic, copy, nullable) NSString *tempFallbackPath;

// AVAssetWriter components
@property (nonatomic, strong, nullable) AVAssetWriter *assetWriter;
@property (nonatomic, strong, nullable) AVAssetWriterInput *videoInput;
@property (nonatomic, strong, nullable) AVAssetWriterInput *audioInput;

// ScreenCaptureKit components (macOS 12.3+)
@property (nonatomic, strong, nullable) id scStream; // SCStream
@property (nonatomic, strong, nullable) id scDelegate; // ScreenRecorderStreamDelegate

// Microphone audio capture
@property (nonatomic, strong, nullable) AVCaptureSession *audioCaptureSession;

// Fallback screencapture CLI task
@property (nonatomic, strong, nullable) NSTask *fallbackTask;

@property (nonatomic, assign) NSInteger targetWidth;
@property (nonatomic, assign) NSInteger targetHeight;
@property (nonatomic, assign) NSInteger targetFPS;

@end

@implementation ScreenRecorderManager

+ (instancetype)sharedManager {
    static ScreenRecorderManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[ScreenRecorderManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _writerQueue = dispatch_queue_create("com.dangtb.ChillScreen.videoWriter", DISPATCH_QUEUE_SERIAL);
        _audioQueue = dispatch_queue_create("com.dangtb.ChillScreen.audioCapture", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)isRecording {
    return _isRecording;
}

- (NSTimeInterval)elapsedSeconds {
    if (!_startDate) return 0;
    return [[NSDate date] timeIntervalSinceDate:_startDate];
}

#pragma mark - Helpers

- (NSDictionary *)videoCompressionSettingsForWidth:(NSInteger)width height:(NSInteger)height fps:(NSInteger)fps {
    SettingsManager *sm = [SettingsManager sharedManager];
    BOOL isHEVC = [sm.videoCodec.uppercaseString isEqualToString:@"HEVC"];
    BOOL isHighQuality = [sm.videoQuality.uppercaseString isEqualToString:@"HIGH"];
    
    // Adaptive bitrate based on pixels, FPS, and codec efficiency
    double bpp = isHEVC ? (isHighQuality ? 0.08 : 0.045) : (isHighQuality ? 0.12 : 0.07);
    NSInteger bitrate = (NSInteger)((double)width * (double)height * (double)fps * bpp);
    bitrate = MAX(400000, MIN(bitrate, 14000000));
    
    NSMutableDictionary *compressionProps = [@{
        AVVideoAverageBitRateKey: @(bitrate),
        AVVideoMaxKeyFrameIntervalKey: @(fps * 3), // 3-sec keyframe for lightweight static screens
        AVVideoExpectedSourceFrameRateKey: @(fps),
        AVVideoAllowFrameReorderingKey: @YES
    } mutableCopy];
    
    if (!isHEVC) {
        compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel;
    }
    
    NSString *codec = isHEVC ? AVVideoCodecTypeHEVC : AVVideoCodecTypeH264;
    
    return @{
        AVVideoCodecKey: codec,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height),
        AVVideoCompressionPropertiesKey: compressionProps,
        AVVideoColorPropertiesKey: @{
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        }
    };
}

- (AVFileType)targetAVFileType {
    SettingsManager *sm = [SettingsManager sharedManager];
    if ([sm.videoFormat.uppercaseString isEqualToString:@"MOV"]) {
        return AVFileTypeQuickTimeMovie;
    }
    return AVFileTypeMPEG4;
}

- (NSString *)formattedDuration:(NSTimeInterval)seconds {
    NSInteger total = (NSInteger)MAX(0, seconds);
    NSInteger mins = total / 60;
    NSInteger secs = total % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)secs];
}

#pragma mark - Start / Stop

- (void)startRecordingScreen:(nullable NSScreen *)screen cropRect:(NSRect)cropRect {
    if (_isRecording || _isStopping) return;
    if (!screen) screen = [NSScreen mainScreen];
    
    _isRecording = YES;
    _isStopping = NO;
    _sessionStarted = NO;
    _startDate = [NSDate date];
    
    SettingsManager *sm = [SettingsManager sharedManager];
    _currentOutputPath = [sm generateNewVideoFilePath];
    _targetFPS = (sm.videoFPS == 60) ? 60 : 30;
    
    NSRect screenFrame = screen.frame;
    BOOL isFullscreen = NSIsEmptyRect(cropRect);
    NSRect effectiveRect = isFullscreen ? NSMakeRect(0, 0, screenFrame.size.width, screenFrame.size.height) : cropRect;
    
    // Calculate pixel dimensions
    BOOL isHighQuality = [sm.videoQuality.uppercaseString isEqualToString:@"HIGH"];
    CGFloat scale = isHighQuality ? screen.backingScaleFactor : 1.0;
    
    NSInteger rawW = (NSInteger)round(effectiveRect.size.width * scale);
    NSInteger rawH = (NSInteger)round(effectiveRect.size.height * scale);
    
    // Cap 1x / Light mode max dimension at 1920px if huge display to keep file ultra-light
    if (!isHighQuality && MAX(rawW, rawH) > 1920) {
        CGFloat ratio = 1920.0 / MAX(rawW, rawH);
        rawW = (NSInteger)(rawW * ratio);
        rawH = (NSInteger)(rawH * ratio);
    }
    
    // Enforce even dimensions (required by HEVC/H.264 encoders)
    _targetWidth = MAX(64, rawW & ~1);
    _targetHeight = MAX(64, rawH & ~1);
    
    // Show non-captured overlay border & control pill
    _overlayWindow = [[RecordingOverlayWindow alloc] initWithScreen:screen cropRect:cropRect];
    __weak typeof(self) weakSelf = self;
    _overlayWindow.onStopClicked = ^{
        [weakSelf stopRecording];
    };
    [_overlayWindow showOverlay];
    
    // Start UI timer
    _uiTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSString *timeStr = [weakSelf formattedDuration:weakSelf.elapsedSeconds];
        [weakSelf.overlayWindow updateTimerText:timeStr];
        if (weakSelf.onRecordingTimerTick) {
            weakSelf.onRecordingTimerTick(timeStr);
        }
    }];
    if (_onRecordingTimerTick) {
        _onRecordingTimerTick(@"00:00");
    }
    
    // Convert Cocoa bottom-left cropRect to top-left screen coordinates
    CGFloat topY = screenFrame.size.height - (effectiveRect.origin.y + effectiveRect.size.height);
    CGRect topLeftLocalRect = CGRectMake(effectiveRect.origin.x, topY, effectiveRect.size.width, effectiveRect.size.height);
    
    // Try ScreenCaptureKit first on macOS 12.3+ if TCC permission is granted
    if (@available(macOS 12.3, *)) {
        if ([[ScreenCaptureManager sharedManager] hasScreenCapturePermission]) {
            [self startWithScreenCaptureKitForScreen:screen sourceRect:topLeftLocalRect];
            return;
        }
    }
    
    // Fallback: screencapture -v + hardware AVAssetWriter re-encode
    [self startWithFallbackScreencaptureForScreen:screen topLeftLocalRect:topLeftLocalRect isFullscreen:isFullscreen];
}

#pragma mark - Engine 1: ScreenCaptureKit + AVAssetWriter

- (void)startWithScreenCaptureKitForScreen:(NSScreen *)screen sourceRect:(CGRect)sourceRect API_AVAILABLE(macos(12.3)) {
    CGDirectDisplayID targetDisplayID = [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
    
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable content, NSError * _Nullable error) {
        if (error || !content || content.displays.count == 0) {
            NSLog(@"[ChillScreen] SCShareableContent unavailable (%@), falling back to screencapture CLI.", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL isFull = (fabs(sourceRect.size.width - screen.frame.size.width) < 2 && fabs(sourceRect.size.height - screen.frame.size.height) < 2);
                [self startWithFallbackScreencaptureForScreen:screen topLeftLocalRect:sourceRect isFullscreen:isFull];
            });
            return;
        }
        
        SCDisplay *matchedDisplay = content.displays.firstObject;
        for (SCDisplay *d in content.displays) {
            if (d.displayID == targetDisplayID) {
                matchedDisplay = d;
                break;
            }
        }
        
        // Setup AVAssetWriter
        NSURL *outputURL = [NSURL fileURLWithPath:self.currentOutputPath];
        [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
        
        NSError *writerErr = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:[self targetAVFileType] error:&writerErr];
        if (writerErr || !self.assetWriter) {
            [self finishWithOutputPath:nil error:writerErr];
            return;
        }
        
        NSDictionary *videoSettings = [self videoCompressionSettingsForWidth:self.targetWidth height:self.targetHeight fps:self.targetFPS];
        self.videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        self.videoInput.expectsMediaDataInRealTime = YES;
        if ([self.assetWriter canAddInput:self.videoInput]) {
            [self.assetWriter addInput:self.videoInput];
        }
        
        // Optional Microphone audio
        if ([SettingsManager sharedManager].recordAudio) {
            NSDictionary *audioSettings = @{
                AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVSampleRateKey: @44100,
                AVNumberOfChannelsKey: @1,
                AVEncoderBitRateKey: @96000
            };
            self.audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
            self.audioInput.expectsMediaDataInRealTime = YES;
            if ([self.assetWriter canAddInput:self.audioInput]) {
                [self.assetWriter addInput:self.audioInput];
                [self setupMicrophoneCapture];
            }
        }
        
        [self.assetWriter startWriting];
        
        // Configure SCStream
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:matchedDisplay excludingWindows:@[]];
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.sourceRect = sourceRect;
        config.width = (size_t)self.targetWidth;
        config.height = (size_t)self.targetHeight;
        config.minimumFrameInterval = CMTimeMake(1, (int32_t)self.targetFPS);
        config.showsCursor = YES;
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        config.queueDepth = 5;
        
        ScreenRecorderStreamDelegate *del = [[ScreenRecorderStreamDelegate alloc] init];
        __weak typeof(self) weakSelf = self;
        del.onVideoSample = ^(CMSampleBufferRef sampleBuffer) {
            [weakSelf handleSCVideoSample:sampleBuffer];
        };
        del.onStreamError = ^(NSError *streamErr) {
            NSLog(@"[ChillScreen] SCStream error: %@", streamErr);
        };
        self.scDelegate = del;
        
        SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:del];
        self.scStream = stream;
        
        NSError *addOutErr = nil;
        [stream addStreamOutput:del type:SCStreamOutputTypeScreen sampleHandlerQueue:self->_writerQueue error:&addOutErr];
        
        [stream startCaptureWithCompletionHandler:^(NSError * _Nullable startErr) {
            if (startErr) {
                NSLog(@"[ChillScreen] SCStream startCapture failed: %@", startErr);
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL isFull = (fabs(sourceRect.size.width - screen.frame.size.width) < 2 && fabs(sourceRect.size.height - screen.frame.size.height) < 2);
                    [weakSelf startWithFallbackScreencaptureForScreen:screen topLeftLocalRect:sourceRect isFullscreen:isFull];
                });
            } else {
                if (weakSelf.audioCaptureSession) {
                    [weakSelf.audioCaptureSession startRunning];
                }
            }
        }];
    }];
}

- (void)handleSCVideoSample:(CMSampleBufferRef)sampleBuffer API_AVAILABLE(macos(12.3)) {
    if (!sampleBuffer || !CMSampleBufferIsValid(sampleBuffer) || _isStopping || !_isRecording) return;
    if (!self.assetWriter || self.assetWriter.status != AVAssetWriterStatusWriting) return;
    
    // Variable Frame Rate optimization: skip idle/incomplete frames to drastically save file size
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        NSDictionary *attachment = (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachments, 0);
        NSNumber *statusNum = attachment[SCStreamFrameInfoStatus];
        if (statusNum && statusNum.integerValue != SCFrameStatusComplete) {
            return;
        }
    }
    
    if (!_sessionStarted) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (CMTIME_IS_VALID(pts)) {
            [self.assetWriter startSessionAtSourceTime:pts];
            _sessionStarted = YES;
        } else {
            return;
        }
    }
    
    if (self.videoInput.isReadyForMoreMediaData) {
        [self.videoInput appendSampleBuffer:sampleBuffer];
    }
}

#pragma mark - Microphone Capture

- (void)setupMicrophoneCapture {
    AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (!mic) return;
    
    AVCaptureDeviceInput *micInput = [AVCaptureDeviceInput deviceInputWithDevice:mic error:nil];
    if (!micInput) return;
    
    _audioCaptureSession = [[AVCaptureSession alloc] init];
    if ([_audioCaptureSession canAddInput:micInput]) {
        [_audioCaptureSession addInput:micInput];
    }
    
    AVCaptureAudioDataOutput *audioOut = [[AVCaptureAudioDataOutput alloc] init];
    [audioOut setSampleBufferDelegate:self queue:_audioQueue];
    if ([_audioCaptureSession canAddOutput:audioOut]) {
        [_audioCaptureSession addOutput:audioOut];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!_sessionStarted || _isStopping || !_isRecording || !self.audioInput) return;
    CFRetain(sampleBuffer);
    dispatch_async(_writerQueue, ^{
        if (self.assetWriter.status == AVAssetWriterStatusWriting && self.audioInput.isReadyForMoreMediaData) {
            [self.audioInput appendSampleBuffer:sampleBuffer];
        }
        CFRelease(sampleBuffer);
    });
}

#pragma mark - Engine 2: Fallback screencapture CLI + Hardware Compression

- (void)startWithFallbackScreencaptureForScreen:(NSScreen *)screen topLeftLocalRect:(CGRect)localRect isFullscreen:(BOOL)isFullscreen {
    _tempFallbackPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"chill_vid_raw_%f.mov", [NSDate timeIntervalSinceReferenceDate]]];
    [[NSFileManager defaultManager] removeItemAtPath:_tempFallbackPath error:nil];
    
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-v", @"-x", nil];
    
    SettingsManager *sm = [SettingsManager sharedManager];
    if (sm.recordAudio) {
        [args addObject:@"-g"];
    }
    if (sm.showMouseClicks) {
        [args addObject:@"-k"];
    }
    
    if (!isFullscreen) {
        // Global top-left display coordinates for -R<x,y,w,h>
        NSScreen *primary = [NSScreen screens].firstObject ?: screen;
        CGFloat primaryH = primary.frame.size.height;
        CGFloat globalX = screen.frame.origin.x + localRect.origin.x;
        CGFloat globalTopY = (primaryH - NSMaxY(screen.frame)) + localRect.origin.y;
        
        NSString *rectArg = [NSString stringWithFormat:@"-R%d,%d,%d,%d",
                             (int)round(globalX),
                             (int)round(globalTopY),
                             (int)MAX(64, round(localRect.size.width)),
                             (int)MAX(64, round(localRect.size.height))];
        [args addObject:rectArg];
    } else {
        NSUInteger idx = [[NSScreen screens] indexOfObject:screen];
        if (idx != NSNotFound) {
            [args addObject:[NSString stringWithFormat:@"-D%lu", (unsigned long)(idx + 1)]];
        }
    }
    
    [args addObject:_tempFallbackPath];
    
    _fallbackTask = [[NSTask alloc] init];
    _fallbackTask.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
    _fallbackTask.arguments = args;
    
    NSError *err = nil;
    [_fallbackTask launchAndReturnError:&err];
    if (err) {
        NSLog(@"[ChillScreen] Fallback screencapture failed: %@", err);
        [self finishWithOutputPath:nil error:err];
    }
}

#pragma mark - Stop & Compress

- (void)stopRecording {
    if (!_isRecording || _isStopping) return;
    _isStopping = YES;
    _isRecording = NO;
    
    [_uiTimer invalidate];
    _uiTimer = nil;
    
    [_overlayWindow closeOverlay];
    _overlayWindow = nil;
    
    if (_audioCaptureSession) {
        [_audioCaptureSession stopRunning];
        _audioCaptureSession = nil;
    }
    
    // Case A: Fallback screencapture task
    if (_fallbackTask) {
        NSTask *task = _fallbackTask;
        _fallbackTask = nil;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (task.isRunning) {
                [task interrupt]; // Sends SIGINT to finalize MOV cleanly
                [task waitUntilExit];
            }
            
            // Transcode & compress via hardware AVAssetWriter to target MP4/MOV HEVC/H264
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempFallbackPath]) {
                [self transcodeAndCompressFile:self.tempFallbackPath toOutputPath:self.currentOutputPath];
            } else {
                [self finishWithOutputPath:nil error:[NSError errorWithDomain:@"ChillScreen" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Không tạo được file video tạm."}]];
            }
        });
        return;
    }
    
    // Case B: ScreenCaptureKit stream
    if (@available(macOS 12.3, *)) {
        if (_scStream) {
            SCStream *stream = (SCStream *)_scStream;
            _scStream = nil;
            _scDelegate = nil;
            
            [stream stopCaptureWithCompletionHandler:^(NSError * _Nullable error) {
                dispatch_async(self->_writerQueue, ^{
                    [self finalizeAssetWriter];
                });
            }];
            return;
        }
    }
    
    dispatch_async(_writerQueue, ^{
        [self finalizeAssetWriter];
    });
}

- (void)finalizeAssetWriter {
    if (!self.assetWriter) {
        [self finishWithOutputPath:nil error:nil];
        return;
    }
    
    if (!_sessionStarted) {
        [self.assetWriter cancelWriting];
        self.assetWriter = nil;
        self.videoInput = nil;
        self.audioInput = nil;
        [self finishWithOutputPath:nil error:nil];
        return;
    }
    
    [self.videoInput markAsFinished];
    if (self.audioInput) {
        [self.audioInput markAsFinished];
    }
    
    [self.assetWriter finishWritingWithCompletionHandler:^{
        AVAssetWriterStatus status = self.assetWriter.status;
        NSError *err = self.assetWriter.error;
        NSString *outPath = (status == AVAssetWriterStatusCompleted) ? self.currentOutputPath : nil;
        
        self.assetWriter = nil;
        self.videoInput = nil;
        self.audioInput = nil;
        
        [self finishWithOutputPath:outPath error:err];
    }];
}

- (void)transcodeAndCompressFile:(NSString *)inputPath toOutputPath:(NSString *)outputPath {
    NSURL *inURL = [NSURL fileURLWithPath:inputPath];
    NSURL *outURL = [NSURL fileURLWithPath:outputPath];
    [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
    
    AVAsset *asset = [AVAsset assetWithURL:inURL];
    NSError *readerErr = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&readerErr];
    
    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (readerErr || videoTracks.count == 0) {
        // Fallback: move raw file if track reading fails
        [[NSFileManager defaultManager] moveItemAtPath:inputPath toPath:outputPath error:nil];
        [self finishWithOutputPath:outputPath error:nil];
        return;
    }
    
    AVAssetTrack *vTrack = videoTracks.firstObject;
    CGSize natSize = vTrack.naturalSize;
    
    // Respect LIGHT vs HIGH scale
    BOOL isHighQuality = [[SettingsManager sharedManager].videoQuality.uppercaseString isEqualToString:@"HIGH"];
    CGFloat maxDim = isHighQuality ? 3840.0 : 1920.0;
    CGFloat scale = 1.0;
    if (MAX(natSize.width, natSize.height) > maxDim) {
        scale = maxDim / MAX(natSize.width, natSize.height);
    }
    NSInteger outW = MAX(64, ((NSInteger)(natSize.width * scale)) & ~1);
    NSInteger outH = MAX(64, ((NSInteger)(natSize.height * scale)) & ~1);
    
    NSDictionary *readerOutSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    };
    AVAssetReaderTrackOutput *vOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:vTrack outputSettings:readerOutSettings];
    vOut.alwaysCopiesSampleData = NO;
    [reader addOutput:vOut];
    
    NSError *writerErr = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outURL fileType:[self targetAVFileType] error:&writerErr];
    NSDictionary *vSettings = [self videoCompressionSettingsForWidth:outW height:outH fps:self.targetFPS];
    AVAssetWriterInput *vIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:vSettings];
    vIn.expectsMediaDataInRealTime = NO;
    [writer addInput:vIn];
    
    // Audio track if present
    AVAssetTrack *aTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetReaderTrackOutput *aOut = nil;
    AVAssetWriterInput *aIn = nil;
    if (aTrack) {
        NSDictionary *aReadSet = @{AVFormatIDKey: @(kAudioFormatLinearPCM)};
        aOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:aTrack outputSettings:aReadSet];
        [reader addOutput:aOut];
        
        NSDictionary *aWriteSet = @{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVSampleRateKey: @44100,
            AVNumberOfChannelsKey: @1,
            AVEncoderBitRateKey: @96000
        };
        aIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:aWriteSet];
        aIn.expectsMediaDataInRealTime = NO;
        [writer addInput:aIn];
    }
    
    [reader startReading];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);
    [vIn requestMediaDataWhenReadyOnQueue:dispatch_queue_create("com.dangtb.ChillScreen.transcodeV", DISPATCH_QUEUE_SERIAL) usingBlock:^{
        while (vIn.isReadyForMoreMediaData) {
            CMSampleBufferRef buf = [vOut copyNextSampleBuffer];
            if (buf) {
                [vIn appendSampleBuffer:buf];
                CFRelease(buf);
            } else {
                [vIn markAsFinished];
                dispatch_group_leave(group);
                break;
            }
        }
    }];
    
    if (aIn && aOut) {
        dispatch_group_enter(group);
        [aIn requestMediaDataWhenReadyOnQueue:dispatch_queue_create("com.dangtb.ChillScreen.transcodeA", DISPATCH_QUEUE_SERIAL) usingBlock:^{
            while (aIn.isReadyForMoreMediaData) {
                CMSampleBufferRef buf = [aOut copyNextSampleBuffer];
                if (buf) {
                    [aIn appendSampleBuffer:buf];
                    CFRelease(buf);
                } else {
                    [aIn markAsFinished];
                    dispatch_group_leave(group);
                    break;
                }
            }
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [writer finishWritingWithCompletionHandler:^{
            [[NSFileManager defaultManager] removeItemAtPath:inputPath error:nil];
            if (writer.status == AVAssetWriterStatusCompleted) {
                [self finishWithOutputPath:outputPath error:nil];
            } else {
                [self finishWithOutputPath:nil error:writer.error];
            }
        }];
    });
}

- (void)finishWithOutputPath:(nullable NSString *)outputPath error:(nullable NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_isRecording = NO;
        self->_isStopping = NO;
        self->_startDate = nil;
        
        if (outputPath && [[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            if ([SettingsManager sharedManager].playSound) {
                [[ScreenCaptureManager sharedManager] playShutterSound];
            }
            
            // Copy video file URL to Clipboard so user can Cmd+V directly into Zalo/Telegram/Finder
            NSPasteboard *pb = [NSPasteboard generalPasteboard];
            [pb clearContents];
            [pb writeObjects:@[[NSURL fileURLWithPath:outputPath]]];
            
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil];
            unsigned long long fileSize = [attrs fileSize];
            NSString *sizeStr = [NSByteCountFormatter stringFromByteCount:(long long)fileSize countStyle:NSByteCountFormatterCountStyleFile];
            
            [[ScreenCaptureManager sharedManager] showNotificationWithTitle:@"ChillScreen Video"
                                                                    message:[NSString stringWithFormat:@"Đã lưu & Copy video (%@): %@", sizeStr, outputPath.lastPathComponent]];
        } else if (error) {
            [[ScreenCaptureManager sharedManager] showNotificationWithTitle:@"ChillScreen Lỗi Quay Video"
                                                                    message:error.localizedDescription];
        }
        
        if (self.onRecordingFinished) {
            self.onRecordingFinished(outputPath, error);
        }
    });
}

@end
