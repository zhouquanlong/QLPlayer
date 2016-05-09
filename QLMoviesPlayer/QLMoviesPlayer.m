//
//  QLMoviesPlayer.m
//  QLPlayer
//
//  Created by 周泉龙 on 16/5/9.
//  Copyright © 2016年 LongQuan. All rights reserved.
//

#import "QLMoviesPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>

#define SELFWIDTH self.bounds.size.width
#define SELFHEIGHT self.bounds.size.height

#define SCREENWIDTH [UIScreen mainScreen].bounds.size.width
#define SCREENHEIGHT [UIScreen mainScreen].bounds.size.height

#define MARGIN 8

//视频播放状态记录
typedef NS_ENUM(NSInteger, VideoPlayerState) {
    VideoPlayerStatePlay,
    VideoPlayerStatePause,
    VideoPlayerStateStop
};

//手指滑动状态记录
typedef NS_ENUM(NSInteger, GestureDirection){
    
    GestureDirectionHorizontalMoved, //水平划动
    GestureDirectionVerticalMoved    //垂直划动
};


#pragma mark - interface
#pragma mark -

@interface QLMoviesPlayer ()

#pragma mark - 播放管理
/** 播放管理者 */
@property(nonatomic, strong) AVPlayerItem *playerItem;
/** 视频播放 */
@property(nonatomic, strong) AVPlayer *player;
/** 播放显示图层 */
@property(nonatomic, strong) AVPlayerLayer *playerLayer;


#pragma mark - UI控件
/** 顶部cover View */
@property(nonatomic, strong) UIView *topView;
/** 顶部cover 背景图片*/
@property(nonatomic, strong) UIImageView *topImgView;
/** 顶部cover 关闭按钮*/
@property(nonatomic, strong) UIButton *closeButton;

/** 底部cover View */
@property(nonatomic, strong) UIView *bottomView;
/** 底部cover View的back image */
@property(nonatomic, strong) UIImageView *bottomImgView;
/** 底部cover 播放开始暂停按钮*/
@property(nonatomic, strong) UIButton *playButton;
/** 底部cover 当前时间label*/
@property(nonatomic, strong) UILabel *currentTimeLabel;
/** 底部cover 总共时间label*/
@property(nonatomic, strong) UILabel *totleTimeLabel;
/** 底部cover 进度条*/
@property(nonatomic, strong) UISlider *progressSlider;
/** 底部cover 全屏按钮*/
@property(nonatomic, strong) UIButton *fullScreenButton;

/** 中间提示view */
@property (strong, nonatomic) UIView *tipsView;
/** View的Back ImgView */
@property (strong, nonatomic) UIImageView *tipsBackImgView;
/** 提示label */
@property (strong, nonatomic) UILabel *tipsLabel;
/** 提示img */
@property (strong, nonatomic) UIImageView *tipsImg;

#pragma mark - 操作
/** 记录划动方向 */
@property (nonatomic, assign) GestureDirection gestureDirection;
/** 视频播放状态 */
@property(nonatomic, assign) VideoPlayerState currentVideoPlayState;
/** 判断是否进入后台 */
@property (nonatomic, assign) BOOL isBecameBack;
/** 是否调节音量,否则调节亮度 */
@property (nonatomic, assign) BOOL isAdjustVolume;
/** 记录是否全屏 */
@property (nonatomic, assign) BOOL isFullScreen;
/** 是否用户操作 */
@property (assign, nonatomic) BOOL isUserOperation;
/** 计时器 */
@property(nonatomic, strong) NSTimer *timer;
/** 记录上一刻的time */
@property (nonatomic, assign) NSTimeInterval tempTime;
/** 记录进退时长 */
@property (nonatomic, assign) CGFloat sumTime;
/** 记录Frame */
@property (nonatomic, assign) CGRect smallFrame;
/** 记录父控制器 */
@property (nonatomic, strong) UIView *superView;
/** 音量控制滑杆 */
@property (nonatomic, strong) UISlider *volumeViewSlider;
@end
#pragma mark - implementation
#pragma mark -

@implementation QLMoviesPlayer

#pragma mark - 对外提供的接口
-(void)playVideoWithUrl:(NSURL *)urlName
{
    self.playerItem = [AVPlayerItem playerItemWithURL:urlName];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    [self.layer insertSublayer:self.playerLayer atIndex:0];
}

#pragma mark - 私有方法
-(void)didClickButton:(UIButton *)sender
{
    switch (sender.tag) {
        case 1:
            if (sender.selected) {
                [self pause];
            }else{
                [self play];
            }
            break;
        case 2:{
            UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
            UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
            switch (interfaceOrientation) {
                case UIInterfaceOrientationPortrait:{
                    [self interfaceOrientation:UIInterfaceOrientationLandscapeRight];
                }
                    break;
                case UIInterfaceOrientationLandscapeRight:{
                    [self interfaceOrientation:UIInterfaceOrientationPortrait];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 3:
            [self removeFromSuperview];
            [self.player replaceCurrentItemWithPlayerItem:nil];
            break;
            
        default:
            break;
    }
}

-(void)addNotification
{
    // app将要进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    // app将要进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    // 设备旋转
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeviceOrientationChange) name:UIDeviceOrientationDidChangeNotification object:nil];
}

/**
    设置系统音量
 */
- (void)systemVolumeView {
    
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    self.volumeViewSlider = nil;
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            self.volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    NSError *setCategoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
}

-(void)addGesture
{
    // 轻拍
    UITapGestureRecognizer *tapGestureRecogizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(signalTapGestureRecogizer:)];
    [self addGestureRecognizer:tapGestureRecogizer];
    
    // 滑动
    UIPanGestureRecognizer *slideGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(slideGestureRecognizer:)];
    [self addGestureRecognizer:slideGestureRecognizer];
}

/**
 轻拍手势
 */
-(void)signalTapGestureRecogizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        self.isUserOperation = YES;
        self.topView.hidden = !self.topView.hidden;
        self.bottomView.hidden = !self.bottomView.hidden;
        self.tipsView.hidden = YES;
    }
}
/**
 滑动手势
 */
-(void)slideGestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer
{
    //根据在view上Pan的位置，确定是调音量还是亮度
    CGPoint locationPoint = [gestureRecognizer locationInView:self];
    
    // 根据上次和本次移动的位置，算速率
    CGPoint veloctyPoint = [gestureRecognizer velocityInView:self];
    
    // 判断是垂直移动还是水平移动
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateBegan:{ // 开始移动
            
            // 使用绝对值来判断移动的方向
            CGFloat x = ABS(veloctyPoint.x);
            CGFloat y = ABS(veloctyPoint.y);
         
            if (x > y) { // 水平移动
                self.gestureDirection = GestureDirectionHorizontalMoved;
                [self progressSliderEventTouchBagin:self.progressSlider];
            }
            else if (x < y){ // 垂直移动
                self.gestureDirection = GestureDirectionVerticalMoved;
                // 开始滑动的时候,状态改为正在控制音量
                if (locationPoint.x > self.bounds.size.width / 2) {
                    self.isAdjustVolume = YES;
                }else { // 状态改为显示亮度调节
                    self.isAdjustVolume = NO;
                }
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.gestureDirection) {
                case GestureDirectionHorizontalMoved:{
                    [self horizontalMoved:veloctyPoint.x]; // 水平移动的方法只要x方向的值
                    [self progressSliderValueChanged:self.progressSlider];
                    break;
                }
                case GestureDirectionVerticalMoved:{
                    [self verticalMoved:veloctyPoint.y]; // 垂直移动方法只要y方向的值
                    break;
                }
                default:
                    break;
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded:{ // 移动停止
            // 移动结束也需要判断垂直或者平移
            switch (self.gestureDirection) {
                case GestureDirectionHorizontalMoved:{
                    [self progressSliderTouchEnd:self.progressSlider];
                    break;
                }
                case GestureDirectionVerticalMoved:{
                    [self performSelector:@selector(allViewHidden) withObject:nil afterDelay:5];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }

    
}

// 播放
-(void)play
{
    // 播放
    [self.player play];
    self.playButton.selected = YES;
    
    [self startTimer];
    self.currentVideoPlayState = VideoPlayerStatePlay;
    [self performSelector:@selector(allViewHidden) withObject:nil afterDelay:2];
}
// 暂停
-(void)pause
{
    self.playButton.selected = NO;
    // 暂停
    [self.player pause];
    
    [self stopTimer];
    self.currentVideoPlayState = VideoPlayerStatePause;
}

// 时间开始
-(void)startTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.8 target:self selector:@selector(UpdateSilderProgressAndTimeLabel) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}
// 时间暂停
-(void)stopTimer
{
    [self.timer invalidate];
}

// 更新进度条和显示时间label
-(void)UpdateSilderProgressAndTimeLabel
{
    // 更新进度条
    self.progressSlider.value = CMTimeGetSeconds(self.player.currentTime) / CMTimeGetSeconds(self.player.currentItem.duration);
    
    // 更新label
    NSTimeInterval currentTimer = CMTimeGetSeconds(self.player.currentTime);
    self.tempTime = currentTimer;
    self.currentTimeLabel.text = [self timerString:currentTimer];

    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    self.totleTimeLabel.text = [self timerString:duration];
}


// 时间格式
-(NSString *)timerString:(NSTimeInterval)time
{
    NSInteger minute = time/ 60;
    NSInteger second = (NSInteger)time %60;
    
    return [NSString stringWithFormat:@"%02ld : %02ld", minute, second];
}
// 隐藏其他view
-(void)allViewHidden
{
    // 如果是用户操作就直接返回
    if (self.isUserOperation) return;
    self.topView.hidden = YES;
    self.bottomView.hidden = YES;
    self.tipsView.hidden = YES;
}
// 更新提示框
-(void)upDateTipsView
{
    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    self.currentTimeLabel.text = [self timerString:currentTime];
    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    self.totleTimeLabel.text = [self timerString:duration];
    
#warning 此处有一个小bug等待修复
    if (currentTime > self.tempTime) {
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Minus"];
    }else {
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Plus"];
    }
    
    self.tipsLabel.text = [NSString stringWithFormat:@"%@ / %@", self.currentTimeLabel.text, self.totleTimeLabel.text];
}

/**
 *  计算progressSlider的值
 */
- (void)horizontalMoved:(CGFloat)value
{
    // 每次滑动需要叠加时间
    self.sumTime += value / 200;
    
    // 需要限定sumTime的范围
    CMTime totalTime           = self.playerItem.duration;
    CGFloat totalMovieDuration = (CGFloat)totalTime.value/totalTime.timescale;
    if (self.sumTime > totalMovieDuration) {
        self.sumTime = totalMovieDuration;
    }else if (self.sumTime < 0){
        self.sumTime = 0;
    }
    self.progressSlider.value = self.sumTime / totalMovieDuration;
}

/**
 *  pan垂直移动的方法
 *
 */
- (void)verticalMoved:(CGFloat)value
{
    if (self.isAdjustVolume) {
        // 更改系统的音量
        self.volumeViewSlider.value      -= value / 10000;
    }else {
        //亮度
        [UIScreen mainScreen].brightness -= value / 10000;
        NSString *brightness             = [NSString stringWithFormat:@"亮度%.0f%%",[UIScreen mainScreen].brightness/1.0*100];
        self.tipsView.hidden      = NO;
        self.tipsLabel.text        = brightness;
        self.tipsImg.image = [UIImage imageNamed:@"Resources.bundle/Lightbulb"];
    }
    
}

#pragma mark - 进度条事件
-(void)silderProgressConfigNotification
{
    [self.progressSlider addTarget:self action:@selector(progressSliderEventTouchBagin:) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnd:) forControlEvents:UIControlEventTouchUpInside];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnd:) forControlEvents:UIControlEventTouchCancel];
    [self.progressSlider addTarget:self action:@selector(progressSliderTouchEnd:) forControlEvents:UIControlEventTouchUpOutside];
}
/** 开始点击到滑竿时 */
-(void)progressSliderEventTouchBagin:(UISlider *)slider
{
    [self pause];
    
    self.isUserOperation = YES;
    self.topView.hidden = NO;
    self.bottomView.hidden = NO;
    self.tipsView.hidden = NO;
}

-(void)progressSliderValueChanged:(UISlider *)slider
{
    NSTimeInterval timer = CMTimeGetSeconds(self.playerItem.duration) * self.progressSlider.value;
    [self.player seekToTime:CMTimeMakeWithSeconds(timer, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    
    [self UpdateSilderProgressAndTimeLabel];
    [self upDateTipsView];
}
-(void)progressSliderTouchEnd:(UISlider *)slider
{
    [self play];
    self.tipsView.hidden = YES;
    self.isUserOperation = NO;
    [self performSelector:@selector(allViewHidden) withObject:nil afterDelay:3];
}

#pragma mark - 监听通知
// app将要变成激活状态
-(void)applicationDidBecomeActive
{
    NSLog(@"applicationDidBecomeActive");
    
    if (self.isBecameBack) {
        if (self.currentVideoPlayState == VideoPlayerStatePlay) {
            [self play];
            self.isBecameBack = NO;
        }
    }
}

// app将要进入后台
-(void)applicationWillResignActive
{
    NSLog(@"applicationWillResignActive");
    [self pause];
    self.isBecameBack = YES;
}

#pragma mark - 监听设备旋转方法
// 设备旋转
-(void)onDeviceOrientationChange
{
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            [self changeSelfToSmallScreen];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [self changeSelfToFullScreen];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [self changeSelfToFullScreen];
            break;
            
        default:
            break;
    }
}
/**
 转换成小屏幕
 */
-(void)changeSelfToSmallScreen
{
    self.frame = self.smallFrame;
    self.fullScreenButton.selected = NO;
    self.isFullScreen = NO;
    
    [self removeFromSuperview];
    [self.superView addSubview:self];
}

/**
 转换成大屏幕
 */
-(void)changeSelfToFullScreen
{
    self.frame = CGRectMake(0, 0, SCREENWIDTH, SCREENHEIGHT);
    self.center = CGPointMake(SCREENWIDTH/2, SCREENHEIGHT/2);
    self.playerLayer.frame = CGRectMake(0, 0, SCREENWIDTH/2, SCREENHEIGHT/2);
    self.playerLayer.position = CGPointMake(SCREENWIDTH, SCREENHEIGHT);
    
    self.fullScreenButton.selected = YES;
    self.isFullScreen = YES;
    
    [self removeFromSuperview];
    [[UIApplication sharedApplication].keyWindow addSubview:self];
}
/**
 *  手动屏幕旋转
 */
- (void)interfaceOrientation:(UIInterfaceOrientation)orientation
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = orientation;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

#pragma mark - 系统方法
-(void)layoutSubviews
{
    [super layoutSubviews];
    
    self.topView.frame = CGRectMake(0, 0, SELFWIDTH, 44);
    self.topImgView.frame = self.topView.bounds;
    self.closeButton.frame = CGRectMake(MARGIN, MARGIN, 28, 28);
    
    self.bottomView.frame = CGRectMake(0, SELFHEIGHT - 44, SELFWIDTH, 44);
    self.bottomImgView.frame = self.bottomView.bounds;
    self.playButton.frame = CGRectMake(MARGIN, MARGIN, 28, 28);
    self.currentTimeLabel.frame = CGRectMake(CGRectGetMaxX(self.playButton.frame) + 4, 0, 52, 44);
    self.progressSlider.frame = CGRectMake(CGRectGetMaxX(self.currentTimeLabel.frame) + 4, 0, SELFWIDTH -44 - 52 - MARGIN - 52 - 44 - MARGIN,  44);
    self.totleTimeLabel.frame = CGRectMake(CGRectGetMaxX(self.progressSlider.frame) + 4, 0, 52, 44);
    self.fullScreenButton.frame = CGRectMake(CGRectGetMaxX(self.totleTimeLabel.frame) + 4, 0, 44, 44);
    
    self.tipsView.center = CGPointMake(SELFWIDTH / 2.0, SELFHEIGHT / 2.0);
    self.tipsView.bounds = CGRectMake(0, 0, 180, 44);
    self.tipsBackImgView.frame = self.tipsView.bounds;
    self.tipsImg.frame = CGRectMake(MARGIN, MARGIN, 28, 28);
    self.tipsLabel.frame = CGRectMake(44, 0, 180 - 44, 44);
    
    self.playerLayer.frame = self.layer.bounds;
    
    self.tipsView.hidden = YES;
    
    // 添加通知监听
    [self addNotification];
    
    // 进度条事件
    [self silderProgressConfigNotification];
    
    // 添加手势
    [self addGesture];
    
    //    获取系统音量
    [self systemVolumeView];
    
    if (self.superView == nil) {
        self.superView = self.superview;
    }
    if (self.smallFrame.size.width == 0) {
        self.smallFrame = self.frame;
    }
}

#pragma mark - 懒加载
-(UIView *)topView
{
    if (_topView == nil) {
        _topView = [[UIView alloc]init];
        [self addSubview:_topView];
    }
    return _topView;
}
-(UIImageView *)topImgView
{
    if (_topImgView == nil) {
        _topImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        _topImgView.alpha = 0.95;
        [self.topView addSubview:_topImgView];
    }
    return _topImgView;
}
-(UIButton *)closeButton
{
    if (_closeButton == nil) {
        _closeButton = [[UIButton alloc]init];
        [_closeButton setImage:[UIImage imageNamed:@"Resources.bundle/X"] forState:UIControlStateNormal];
        [_closeButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        _closeButton.tag = 3;
        [self.topView addSubview:_closeButton];
    }
    return _closeButton;
}

-(UIView *)bottomView
{
    if (_bottomView == nil) {
        _bottomView = [[UIView alloc]init];
        [self addSubview:_bottomView];
    }
    return _bottomView;
}

-(UIImageView *)bottomImgView
{
    if (_bottomImgView == nil) {
        _bottomImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        [self.bottomView addSubview:_bottomImgView];
    }
    return _bottomImgView;
}

-(UIButton *)playButton
{
    if (_playButton == nil) {
        _playButton = [[UIButton alloc] init];
        [_playButton setImage:[UIImage imageNamed:@"Resources.bundle/Play"] forState:UIControlStateNormal];
        [_playButton setImage:[UIImage imageNamed:@"Resources.bundle/Pause"] forState:UIControlStateSelected];
        [_playButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        _playButton.tag = 1;
        [self.bottomView addSubview:_playButton];
    }
    return _playButton;
}
// 当前时间
-(UILabel *)currentTimeLabel
{
    if (_currentTimeLabel == nil) {
        _currentTimeLabel = [[UILabel alloc] init];
        _currentTimeLabel.text = @"00 : 00";
        _currentTimeLabel.font = [UIFont systemFontOfSize:14];
        _currentTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomView addSubview:_currentTimeLabel];
    }
    return _currentTimeLabel;
}
// 总共时间
-(UILabel *)totleTimeLabel
{
    if (_totleTimeLabel == nil) {
        _totleTimeLabel = [[UILabel alloc] init];
        _totleTimeLabel.text = @"00 : 00";
        _totleTimeLabel.font = [UIFont systemFontOfSize:14];
        _totleTimeLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomView addSubview:_totleTimeLabel];
    }
    return _totleTimeLabel;
}
// 进度条
-(UISlider *)progressSlider
{
    if (_progressSlider == nil) {
        _progressSlider = [[UISlider alloc] init];
        [_progressSlider setThumbImage:[UIImage imageNamed:@"Resources.bundle/Point"] forState:UIControlStateNormal];
        [_progressSlider setMinimumTrackImage:[UIImage imageNamed:@"Resources.bundle/MinimumTrackImage"] forState:UIControlStateNormal];
        [self.bottomView addSubview:_progressSlider];
    }
    return _progressSlider;
}
// 全屏按钮
-(UIButton *)fullScreenButton
{
    if (_fullScreenButton == nil) {
        _fullScreenButton = [[UIButton alloc] init];
        [_fullScreenButton setImage:[UIImage imageNamed:@"Resources.bundle/FullScreen"] forState:UIControlStateNormal];
        [_fullScreenButton addTarget:self action:@selector(didClickButton:) forControlEvents:UIControlEventTouchUpInside];
        _fullScreenButton.tag = 2;
        [self.bottomView addSubview:_fullScreenButton];
    }
    return _fullScreenButton;
}
// 中间提示view
- (UIView *)tipsView {
    if (_tipsView == nil) {
        _tipsView = [UIView new];
        _tipsView.layer.cornerRadius = 8;
        _tipsView.layer.masksToBounds = YES;
        [self addSubview:_tipsView];
    }
    return _tipsView;
}
// 提示背景图片
-(UIImageView *)tipsBackImgView {
    if (_tipsBackImgView == nil) {
        _tipsBackImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Resources.bundle/coverBg"]];
        _tipsBackImgView.alpha = .7;
        [self.tipsView addSubview:_tipsBackImgView];
    }
    return _tipsBackImgView;
}
// 中间提示头像
- (UIImageView *)tipsImg {
    if (_tipsImg == nil) {
        _tipsImg = [UIImageView new];
        [self.tipsView addSubview:_tipsImg];
    }
    return _tipsImg;
}
// 提示label
- (UILabel *)tipsLabel {
    if (_tipsLabel == nil) {
        _tipsLabel = [UILabel new];
        _tipsLabel.font = [UIFont systemFontOfSize:15];
        _tipsLabel.textAlignment = NSTextAlignmentCenter;
        [self.tipsView addSubview:_tipsLabel];
    }
    return _tipsLabel;
}


@end
