//
//  ViewController.m
//  QLPlayer
//
//  Created by 周泉龙 on 16/5/9.
//  Copyright © 2016年 LongQuan. All rights reserved.
//

#import "ViewController.h"
#import "QLMoviesPlayer.h"

#define SCREENW [UIScreen mainScreen].bounds.size.width
#define SCREENH [UIScreen mainScreen].bounds.size.height

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    QLMoviesPlayer *meviesPlay = [[QLMoviesPlayer alloc]init];
    
//    meviesPlay.backgroundColor = [UIColor orangeColor];
    
    meviesPlay.frame = CGRectMake(0, 100, SCREENW, SCREENW/16 *9 + 40);
    [self.view addSubview:meviesPlay];
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Cupid_高清.mp4" withExtension:nil];
    [meviesPlay playVideoWithUrl:url];
}

//-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//{
//
// // 在子线程中调用download方法下载图片
////    [self performSelectorInBackground:@selector(download) withObject:nil];
//
//
//    NSThread *thread = [NSThread currentThread];
//    NSLog(@"%@",thread);
//
//    [self performSelector:@selector(download:) onThread:thread withObject:self waitUntilDone:YES];
//
//}
//
//-(void)download:(NSString *)str
//{
//
//   NSThread *thread = [NSThread currentThread];
//    NSLog(@"%@",thread);
//}


@end
