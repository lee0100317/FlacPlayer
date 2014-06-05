//
//  ViewController.m
//  FlacPlayer
//
//  Created by hao.li on 13-4-9.
//  Copyright (c) 2013年 buct. All rights reserved.
//

#import "ViewController.h"
//#import "FLAC/stream_decoder.h"
#import "decodeTest.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onClickDecode:(UIButton *)sender {
    NSString *apePath = [[NSBundle mainBundle] pathForResource:@"1" ofType:@"FLAC"];
    assert(apePath);
    
    NSArray*cacPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString*cachePath = [cacPath objectAtIndex:0];
    NSString *outFilePath = [NSString stringWithFormat:@"%@/1.wav", cachePath];
    
    char *argv[2] = {0};
    char *pszSrc = new char[strlen([apePath UTF8String]) + 1];
    char *pszDes = new char[strlen([outFilePath UTF8String]) + 1];
    
    bzero(pszSrc, strlen([apePath UTF8String]) + 1);
    bzero(pszDes, strlen([outFilePath UTF8String]) + 1);
    
    strcpy(pszDes, [outFilePath UTF8String]);
    strcpy(pszSrc, [apePath UTF8String]);
    
    argv[0] = pszSrc;
    argv[1] = pszDes;
    mainFuns(pszSrc, pszDes);
    
}
@end
