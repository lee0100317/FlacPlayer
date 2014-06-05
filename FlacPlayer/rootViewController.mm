//
//  rootViewController.m
//  Ape_Demo
//
//  Created by hao.li on 13-2-28.
//  Copyright (c) 2013年 kuwo. All rights reserved.
//

#import "rootViewController.h"
//#include "ClApePlayer.h"
#import "APEPlayer.h"

#define PLAYER_SCHEDULE_REFRESH_FREQUNCY 1

@interface rootViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, retain) NSMutableArray *apeFiles;
@property (nonatomic, assign) APEPlayer *m_player;
@property (nonatomic, assign) BOOL isSeeking;

@end

@implementation rootViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.isSeeking = NO;
    }
    return self;
}

- (NSString *) apeFilePath {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString *path = [paths objectAtIndex:0];
    path = [path stringByAppendingString:@"/APE"];
    if (![manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) {
        assert(1);
    }
    return path;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    NSString *path = [self apeFilePath];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:path];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:42];
    self.apeFiles = files;
    NSString *filename ;
    while (filename = [direnum nextObject]) {
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"flac"]) {
            [self.apeFiles addObject: filename];
        }
    }
    self.m_player = [[APEPlayer alloc] init];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView reloadData];
    [self.sliderSchdule addTarget:self action:@selector(onSliderSeek:) forControlEvents:UIControlEventValueChanged];
    [self.sliderSchdule addTarget:self action:@selector(onSliderSeekBegin:) forControlEvents:UIControlEventTouchDown];
    [self.sliderSchdule addTarget:self action:@selector(onSliderSeekEnd:) forControlEvents:UIControlEventTouchUpInside];;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self.m_player release];
    self.m_player = NULL;
    [_apeFiles release];
    [_tableView release];
    [_labelSchdule release];
    [_sliderSchdule release];
    [_buttonPrev release];
    [_buttonPlayPause release];
    [_buttonNext release];
    [super dealloc];
}
- (void)viewDidUnload {
    [self setTableView:nil];
    [self setLabelSchdule:nil];
    [self setSliderSchdule:nil];
    [self setButtonPrev:nil];
    [self setButtonPlayPause:nil];
    [self setButtonNext:nil];
    [super viewDidUnload];
}

#pragma mark - uitable datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.apeFiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
//        cell.selectionStyle = UITableViewCellSelectionStyleNone;
//        cell.accessoryType =  UITableViewCellAccessoryNone;
    }
    cell.textLabel.text = [self.apeFiles objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    NSString *name = [self.apeFiles objectAtIndex:indexPath.row];
    NSString *fullPath = [[self apeFilePath] stringByAppendingFormat:@"/%@", name ];

    [self.m_player setPlayerMediaItemInfo:fullPath];
    NSTimeInterval fDuring = [self.m_player duration];
    NSTimeInterval fSchedule = [self.m_player schedule];
    [self updateProgressLabel:fSchedule during:fDuring];
    [self.m_player play];

    [self performSelectorOnMainThread:@selector(resetScheduleTimer) withObject:nil waitUntilDone:NO];
//    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// time: time in millisecond, upRound: round up or down if less than 1 second
// mm:ss
NSString* TimeToString(NSInteger time, BOOL upRound) {
    NSMutableString* string = [NSMutableString stringWithCapacity:10];
    if (time < 0) {
        [string appendString:@"-"];
        time = -time;
    }
    if (upRound) {
        time += 999;
    }
    int tmp = time / 1000;
    int sec = tmp % 60;
    int min = tmp /= 60;
    [string appendFormat:@"%02d:%02d", min, sec];
    return string;
}

- (void)updateProgressLabel:(NSTimeInterval)schedule during:(NSTimeInterval)during {
    NSInteger t1 =  schedule * 1000;
    NSInteger t2 = during * 1000;
    if(t1 < 0 || t1 > t2)
        return;
    self.labelSchdule.text = [NSString stringWithFormat:@"%@ | %@", TimeToString(t1, t1 == t2), TimeToString((NSInteger)(during * 1000), FALSE)];
    if (t2 < 0.00001) {
        self.sliderSchdule.value = 0;
    } else {
        self.sliderSchdule.value = t1 * 1.0 / t2;
    }
    
}

#pragma mark play control

- (IBAction)onButtonClickPrev:(UIBarButtonItem *)sender {
    sleep(2);
}

- (IBAction)onButtonClickPlayPause:(UIBarButtonItem *)sender {
    if (self.m_player && [self.m_player isPlaying]) {
        [self.m_player pause];
    } else if (self.m_player && ![self.m_player isPlaying]) {
        [self.m_player play];
    }
}

- (IBAction)onButtonClickNext:(UIBarButtonItem *)sender {
}

#pragma mark Player Notify process

- (void) scheduleTimerCallback:(NSTimer*)timer {
    if (self.isSeeking) {
        return;
    }
    NSTimeInterval fDuring = [self.m_player duration];
    NSTimeInterval fSchedule = [self.m_player schedule];
    [self updateProgressLabel:fSchedule during:fDuring];
}

- (void) resetScheduleTimer {
    if ([self.m_player isPlaying]) {
        if (_mpTimer == nil) {
            _mpTimer = [NSTimer timerWithTimeInterval:1.0/PLAYER_SCHEDULE_REFRESH_FREQUNCY target:self selector:@selector(scheduleTimerCallback:) userInfo:nil repeats:YES];
            [_mpTimer retain];
            [[NSRunLoop mainRunLoop] addTimer:_mpTimer forMode:NSDefaultRunLoopMode];
        }
    } else {
        if (_mpTimer != nil) {
            [_mpTimer invalidate];
            [_mpTimer release];
            _mpTimer = nil;
        }
    }
}

- (void)onSliderSeek:(NSObject *)sender {
    self.isSeeking = YES;
}

- (void)onSliderSeekBegin:(NSObject *)sender {
    self.isSeeking = YES;
}

- (void)onSliderSeekEnd:(NSObject *)sender {
    self.isSeeking = NO;
    NSTimeInterval offset = self.sliderSchdule.value * [self.m_player duration];
    NSLog(@"seek to %f", offset);
    [self.m_player seek:offset];
}

@end
