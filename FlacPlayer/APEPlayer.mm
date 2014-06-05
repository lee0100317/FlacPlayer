//
//  APEPlayer.m
//  KWCore
//
//  Created by hao.li on 13-3-13.
//  Copyright (c) 2013年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import "APEPlayer.h"
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioSession.h>

#define BLOCKS_PER_DECODE 9216

@interface APEPlayer ()
{
    //音频队列
    AudioQueueRef m_Queue;
    AudioStreamBasicDescription m_PacketDescs;
    AudioQueueBufferRef m_Buffers[NUM_BUFFERS];
    bool _isInterrpted;
    bool _workingThreadWorking;
    
}

@property (nonatomic, assign) PlayState playStatePrivate;
@property (nonatomic, assign) UInt32 totalBlocks;
@property (nonatomic, assign) UInt32 decodedBlocks;
@property (nonatomic, assign) id delegate;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, retain) NSThread *thread;


@end

#pragma mark cpp style callback funcs

void OutputCallback(void *inUserData,AudioQueueRef inAQ, AudioQueueBufferRef buffer)
{
    APEPlayer *player = static_cast<APEPlayer *>(inUserData);
    int nBlockDecoded = 0;
    int result = player->m_pDecompress->GetData((char *) buffer->mAudioData, BLOCKS_PER_DECODE, &nBlockDecoded);
//    NSLog(@"decode Block: %d", nBlockDecoded);
    if (nBlockDecoded > 0 && result == 0) {
        int bufferSize = nBlockDecoded * player->m_pDecompress->GetInfo(APE_INFO_BYTES_PER_SAMPLE) *
                            player->m_pDecompress->GetInfo(APE_INFO_CHANNELS);
        buffer->mAudioDataByteSize = bufferSize;
        AudioQueueEnqueueBuffer(inAQ, buffer, 0, NULL);
    } else {
        AudioQueueStop(inAQ, false);
        player.playState = PlayStateStopped;
    }
    
//    fwrite(buffer->mAudioData, 1, buffer->mAudioDataByteSize, player->flog);
}

@implementation APEPlayer 

- (void)dealloc {
    if (m_pDecompress) {
        delete m_pDecompress;
        m_pDecompress = NULL;
    }
    [_filePath release];
    if (m_Queue) {
        AudioQueueDispose(m_Queue, YES);
        m_Queue = 0;
    }
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        _isInterrpted = NO;
        _playStatePrivate = PLayStateUndefined;
        m_pDecompress = NULL;
        _totalBlocks = 0;
        _decodedBlocks = 0;
        _delegate = nil;
        m_pDecompress = NULL;
        m_seekTime = 0;
        _delegate = nil;
        _workingThreadWorking = false;
//        m_pDecompress = new ClFlacDecompress();
    }
    return self;
}

#pragma mark - thread

- (void)threadMain:(NSObject *)obj {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // keep the runloop from exiting
	CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
	CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);

    while (1) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, NO);
        NSLog(@"run loop once");
    }
    
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
	CFRelease(source);
    [pool release];
    return;     
}

- (void) setPlayState:(PlayState)state {
    self.playStatePrivate = state;
}

- (void) setPlayStatePrivate:(PlayState)playStatePrivate {
    if (_playStatePrivate != playStatePrivate) {
        _playStatePrivate = playStatePrivate;
        if (self.delegate) {
            [self.delegate onPlayStateChanged];
        }
    }
}

#pragma mark - callback func

- (void) onAudioInterruption:(UInt32)interruptionState {
	if (interruptionState == kAudioSessionBeginInterruption)
	{
        //NSLog(@"Audio interruption begin");
//		AudioSessionSetActive( false );
        if ([self isPlaying])
        {
            [self pause];
            _isInterrpted = TRUE;
        }
	}
	else if (interruptionState == kAudioSessionEndInterruption)
	{
		AudioSessionSetActive( true );
        if (_isInterrpted) {
            [self play];
            _isInterrpted = FALSE;
        }
	}
}

#pragma mark - AudioQueue Funcs

- (void)cleanBuffer {
    if (m_Queue) {
        AudioQueueStop(m_Queue, YES);
        for (int i=0; i<NUM_BUFFERS; i++) {
            m_Buffers[i]->mAudioDataByteSize = 0;
        }
    }
    self.playStatePrivate = PlayStatePaused;
}

- (void)destory {
    if (m_Queue) {
        AudioQueueFlush(m_Queue);
        AudioQueueStop(m_Queue, YES);
        
        UInt32 playing = 0;
        UInt32 size = sizeof(playing);
        
        bool isPlaying = true;
        while (isPlaying) {
            OSStatus err = AudioQueueGetProperty(m_Queue, kAudioQueueProperty_IsRunning, &playing, &size);
            if (err == noErr) {
                isPlaying = (bool)(playing != 0);
            } else {
                isPlaying = false;
            }
            usleep(1000 * 10);
        }
        AudioQueueDispose(m_Queue, YES);
        m_Queue = NULL;
    }
    if (m_pDecompress) {
        delete m_pDecompress;
        m_pDecompress = NULL;
    }
    m_seekTime = 0;
    self.playStatePrivate = PlayStateStopped;
}

- (bool)create {
    [self destory];
    bool result = true;

    if (self.filePath == nil || [self.filePath length] == 0) {
        self.playStatePrivate = PlayStateFailed;
        return NO;
    }
    if (m_pDecompress == NULL) {
        m_pDecompress = new ClFlacDecompress();
    }
    m_pDecompress->InitializeDecompressor([self.filePath UTF8String]);
    
    if (!result) {
        self.playStatePrivate = PlayStateFailed;
        return NO;
    }
    int sampleRate = m_pDecompress->GetInfo(APE_INFO_SAMPLE_RATE);
    int chanel = m_pDecompress->GetInfo(APE_INFO_CHANNELS);
    int bps = m_pDecompress->GetInfo(APE_INFO_BITS_PER_SAMPLE);
    FillOutASBDForLPCM(m_PacketDescs, sampleRate, chanel, bps, bps, false, false);
    
    OSErr n = AudioQueueNewOutput(&m_PacketDescs, OutputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &m_Queue);
    
    unsigned int nBufferSize = bps / 8 * BLOCKS_PER_DECODE * chanel;
    for (int i=0; i<NUM_BUFFERS && n == noErr; i++) {
        n = AudioQueueAllocateBuffer(m_Queue, nBufferSize, &m_Buffers[i]);
    }
    return n = noErr;
}

- (bool)checkQuqueplaying:(AudioQueueRef)AQ {
    if (AQ == NULL) {
        throw -1;
    }
    OSStatus errCode = -1;
    UInt32 nData = 0;
    UInt32 nSize = sizeof(nData);
    errCode = AudioQueueGetProperty(AQ, kAudioQueueProperty_IsRunning, (void *)&nData, &nSize);
    if (errCode) {
        throw -2;
    }
    if (nData != 0) {
        return true;
    } else {
        return false;
    }
}

#pragma mark - implement of protocol MediaPlayerDelegate

- (PlayState) playState {
    return self.playStatePrivate;
}
- (NSTimeInterval) schedule { //当前播到哪里
    if (m_Queue == NULL || m_pDecompress == NULL) {
        return 0;
    }
    AudioTimeStamp queueTime;
    Boolean discontinuity;
    OSStatus err = AudioQueueGetCurrentTime(m_Queue, NULL, &queueTime, &discontinuity);
    if (err != 0) {
        return 0;
    }
    Float64 schedule = m_seekTime + queueTime.mSampleTime / m_pDecompress->GetInfo(APE_INFO_SAMPLE_RATE);
    return schedule;
    
}

- (NSTimeInterval) duration {

    if (m_Queue == 0 || m_pDecompress == NULL) {
        return 0;
    }
    
#ifdef MONKEY
    Float64 result = m_pDecompress->GetInfo(APE_INFO_TOTAL_BLOCKS) / m_pDecompress->GetInfo(APE_INFO_SAMPLE_RATE);
#else
    Float64 result =
    m_pDecompress->GetInfo(APE_INFO_BLOCK_ALIGN) * m_pDecompress->GetInfo(APE_INFO_TOTAL_BLOCKS) /
    ( m_pDecompress->GetInfo(APE_INFO_SAMPLE_RATE) * m_pDecompress->GetInfo(APE_INFO_CHANNELS) );
#endif
    
    return result;
}

- (NSTimeInterval) playDuration {
    return [self duration];
}

- (float) volume {
    return 0.5;
}
- (void) setVolume:(float)volume {
    //TODO:
}

- (BOOL) isPlaying {
    return self.playStatePrivate == PlayStatePlaying;
}

- (BOOL) isBuffering {
    return false;
}

- (void) setPlayerEventHandler:(id)eventHandler {
    self.delegate = eventHandler;
}

- (BOOL) setPlayerMediaItemInfo:(NSString *)filePath {
//    [self performSelector:@selector(setPlayerMediaItemInfoThread:) onThread:self.thread withObject:filePath waitUntilDone:NO];
    [self setPlayerMediaItemInfoThread:filePath];
    return YES;
}

- (void) setPlayerMediaItemInfoThread:(NSString *)filePath {
    if (filePath == nil) {
        return;
    }
    self.filePath = filePath;
    [self destory];
    [self create];
}

- (BOOL) play {
//    [self performSelector:@selector(playThread:) onThread:self.thread withObject:self waitUntilDone:NO];
    [self playThread:self];
    return YES;
}

- (void)playThread:(NSObject *)obj {
    BOOL isInited = YES;
    for (int i=0; i<NUM_BUFFERS; ++i) {
        if (m_Buffers[i] == NULL) {
            isInited = NO;
            break;
        }
    }
    assert(isInited);
    if (!isInited) {
        _workingThreadWorking = false;
        return;
    }
    
    BOOL bNeedFillBuffer = YES;
    for (int i=0; i<NUM_BUFFERS; ++i) {
        if (m_Buffers[i]->mAudioDataByteSize != 0) {
            bNeedFillBuffer = NO;
            break;
        }
    }
    
    if (bNeedFillBuffer) {
        for (int i=0; i<NUM_BUFFERS; ++i) {
            OutputCallback(self, m_Queue, m_Buffers[i]);
        }
    }
    
    OSStatus n = noErr;
    if (self.playStatePrivate == PlayStatePlaying) {
        n = AudioQueuePause(m_Queue);
        if (n == noErr) {
            self.playStatePrivate = PlayStatePaused;
        }
    } else {
        n = AudioQueueStart(m_Queue, NULL);
        if (n == noErr) {
            self.playStatePrivate = PlayStatePlaying;
        }
    }
    _workingThreadWorking = false;
    return;// n == noErr;
}

- (void) pause {
//    [self performSelector:@selector(pauseThread:) onThread:self.thread withObject:self waitUntilDone:NO];
//    fclose(flog);
    [self pauseThread:self];
    
}

- (void) pauseThread:(NSObject *)obj {
    assert(m_Queue);
    if (m_Queue == 0) {
        return;
    }
    if ([self checkQuqueplaying:m_Queue]) {
        OSStatus n = AudioQueuePause(m_Queue);
        if (0 == n)
        {
            self.playStatePrivate = PlayStatePaused;
        }
    }
}

- (void) stop {
//    [self performSelector:@selector(stopThread:) onThread:self.thread withObject:self waitUntilDone:NO];
    [self stopThread:self];
}

- (void)stopThread:(NSObject *)obj {
    [self destory];
}

- (BOOL) seek:(NSTimeInterval)schedule {
// [self performSelector:@selector(seekThread:) onThread:self.thread withObject:[NSNumber numberWithDouble:schedule] waitUntilDone:NO];
    [self seekThread:[NSNumber numberWithDouble:schedule]];
    return YES;
}

- (void)seekThread:(NSNumber *)param {
    NSTimeInterval schedule = [param doubleValue];
    NSLog(@"seek to %f in sec thread", schedule);
    if ( m_pDecompress == NULL || m_Queue == 0 || schedule > [self duration] ) {
        return;
    }
    m_seekTime = schedule;
    unsigned int nBlockOffset = schedule * self->m_pDecompress->GetInfo(APE_INFO_TOTAL_BLOCKS) / [self duration];
    [self cleanBuffer];
    self->m_pDecompress->Seek(nBlockOffset);
    [self play];
}

@end
