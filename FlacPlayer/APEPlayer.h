//
//  APEPlayer.h
//  KWCore
//
//  Created by hao.li on 13-3-13.
//  Copyright (c) 2013年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "FlacDecompress.h"

typedef enum _PlayState {
    PLayStateUndefined = 0,
    PlayStateBuffering,
    //PlayStatePrepareing,
    PlayStatePlaying,
    PlayStatePaused,
    PlayStateStopped,
    PlayStateBufferingFailed,
    //PlayStateDecodeError,
    //PlayStatePlayError,
    PlayStateFailed,
} PlayState;

#define NUM_BUFFERS 3

@interface APEPlayer : NSObject //<MediaPlayerDelegate>
{
@public

    ClFlacDecompress *m_pDecompress;
    NSTimeInterval m_seekTime;
    FILE *flog;
}

/*************************************************************************
 protocol
 *************************************************************************/

- (PlayState) playState;
- (NSTimeInterval) schedule;  //当前播到哪里
- (NSTimeInterval) duration;  //歌曲总长
- (NSTimeInterval) playDuration; //

- (float) volume;
- (void) setVolume:(float)volume;

- (BOOL) isPlaying;
- (BOOL) isBuffering;

- (void) setPlayerEventHandler:(id)eventHandler;

- (BOOL) setPlayerMediaItemInfo:(NSString *)filePath;

- (BOOL) play;
- (void) pause;
- (void) stop;

- (BOOL) seek:(NSTimeInterval)schedule;

/*************************************************************************
 protocol end
 *************************************************************************/

- (void) setPlayState:(PlayState)state;
- (void) onAudioInterruption:(UInt32)interruptionState;

@end
