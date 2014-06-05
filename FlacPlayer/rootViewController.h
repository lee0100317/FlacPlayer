//
//  rootViewController.h
//  Ape_Demo
//
//  Created by hao.li on 13-2-28.
//  Copyright (c) 2013年 kuwo. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface rootViewController : UIViewController
{
    NSTimer* _mpTimer;
}

@property (retain, nonatomic) IBOutlet UITableView *tableView;
@property (retain, nonatomic) IBOutlet UILabel *labelSchdule;
@property (retain, nonatomic) IBOutlet UISlider *sliderSchdule;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *buttonPrev;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *buttonPlayPause;
@property (retain, nonatomic) IBOutlet UIBarButtonItem *buttonNext;

- (IBAction)onButtonClickPrev:(UIBarButtonItem *)sender;
- (IBAction)onButtonClickPlayPause:(UIBarButtonItem *)sender;
- (IBAction)onButtonClickNext:(UIBarButtonItem *)sender;

@end
