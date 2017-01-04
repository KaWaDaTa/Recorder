//
//  ViewController.m
//  Recorder
//
//  Created by appteam on 2017/1/4.
//  Copyright © 2017年 colin.liu. All rights reserved.
//  http://www.jianshu.com/p/7c57c58c253d

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
@property (nonatomic, strong) AVCaptureConnection *captureConnection;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) UILabel *videoSize;
@end

@implementation ViewController

- (AVCaptureSession *)captureSession
{
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}

//- (AVCaptureConnection *)captureConnection
//{
//    if (!_captureConnection) {
//        _captureConnection = [[AVCaptureConnection alloc] init];
//    }
//    return _captureConnection;
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setupSession];
    
    UIButton *take = [UIButton buttonWithType:UIButtonTypeCustom];
    [take addTarget:self action:@selector(takeMovie:) forControlEvents:UIControlEventTouchUpInside];
    [take setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [take setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
    [take setTitle:@"take" forState:UIControlStateNormal];
    [take setTitle:@"taking" forState:UIControlStateSelected];
    take.frame = CGRectMake(50, 50, 100, 50);
    [self.view addSubview:take];
    
    UIButton *compress = [UIButton buttonWithType:UIButtonTypeCustom];
    [compress addTarget:self action:@selector(compressVideo:) forControlEvents:UIControlEventTouchUpInside];
    compress.frame = CGRectMake(200, 50, 100, 50);
    [compress setTitle:@"compress" forState:UIControlStateNormal];
    [compress setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:compress];
}

- (void)setupSession {
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];//分辨率
    }
    AVCaptureDevice *videoCaptureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!videoCaptureDevice) {
        NSLog(@"error:AVCaptureDevicePositionBack");
        return;
    }
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    NSError *vError;
    self.videoCaptureDeviceInput = ({
        AVCaptureDeviceInput *videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:&vError];
        if (vError) {
            NSLog(@"error:videoCaptureDeviceInput");
        }
        
        videoCaptureDeviceInput;
    });
    
    NSError *aError;
    self.audioCaptureDeviceInput = ({
        AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&aError];
        if (aError) {
            NSLog(@"error:audioCaptureDeviceInput");
        }
        
        audioCaptureDeviceInput;
    });
    
    self.captureMovieFileOutput =({
        AVCaptureMovieFileOutput *captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        
        captureMovieFileOutput;
    });
    
    if ([_captureSession canAddInput:self.videoCaptureDeviceInput]) {
        [_captureSession addInput:self.videoCaptureDeviceInput];
    }
    if ([_captureSession canAddInput:self.audioCaptureDeviceInput]) {
        [_captureSession addInput:self.audioCaptureDeviceInput];
    }
    if ([_captureSession canAddOutput:self.captureMovieFileOutput]) {
        [_captureSession addOutput:self.captureMovieFileOutput];
        self.captureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([self.captureConnection isVideoStabilizationSupported]) {
            self.captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
    }
    self.captureVideoPreviewLayer = ({
        AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
        captureVideoPreviewLayer.frame = self.view.bounds;
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.view.layer addSublayer:captureVideoPreviewLayer];
        
        captureVideoPreviewLayer;
    });
    
    
    [_captureSession startRunning];
}

- (void)takeMovie:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        self.captureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([self.captureConnection isVideoStabilizationSupported]) {
            self.captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        // 开启视频防抖模式
        AVCaptureVideoStabilizationMode stabilizationMode = AVCaptureVideoStabilizationModeCinematic;
        if ([self.videoCaptureDeviceInput.device.activeFormat isVideoStabilizationModeSupported:stabilizationMode]) {
            [self.captureConnection setPreferredVideoStabilizationMode:stabilizationMode];
        }
        //如果支持多任务则则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        // 预览图层和视频方向保持一致,这个属性设置很重要，如果不设置，那么出来的视频图像可以是倒向左边的。
        self.captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
        
        // 设置视频输出的文件路径，这里设置为 temp 文件
        NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"movie.mp4"];
        
        // 路径转换成 URL 要用这个方法，用 NSBundle 方法转换成 URL 的话可能会出现读取不到路径的错误
        NSURL *fileUrl=[NSURL fileURLWithPath:outputFielPath];
        
        // 往路径的 URL 开始写入录像 Buffer ,边录边写
        [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    else {
        // 取消视频拍摄
        [self.captureMovieFileOutput stopRecording];
        [self.captureSession stopRunning];
    }
}

// 压缩视频
- (void)compressVideo:(UIButton *)sender
{
    NSString *cachePath=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *savePath=[NSTemporaryDirectory() stringByAppendingPathComponent:@"movie.mp4"];
    NSURL *saveUrl=[NSURL fileURLWithPath:savePath];
    
    // 通过文件的 url 获取到这个文件的资源
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:saveUrl options:nil];
    // 用 AVAssetExportSession 这个类来导出资源中的属性
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    // 压缩视频
    if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality]) { // 导出属性是否包含低分辨率
        // 通过资源（AVURLAsset）来定义 AVAssetExportSession，得到资源属性来重新打包资源 （AVURLAsset, 将某一些属性重新定义
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetLowQuality];
        // 设置导出文件的存放路径
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
        NSDate    *date = [[NSDate alloc] init];
        NSString *outPutPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"output-%@.mp4",[formatter stringFromDate:date]]];
        exportSession.outputURL = [NSURL fileURLWithPath:outPutPath];
        
        // 是否对网络进行优化
        exportSession.shouldOptimizeForNetworkUse = true;
        
        // 转换成MP4格式
        exportSession.outputFileType = AVFileTypeMPEG4;
        
        // 开始导出,导出后执行完成的block
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            // 如果导出的状态为完成
            if ([exportSession status] == AVAssetExportSessionStatusCompleted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 更新一下显示包的大小
                    self.videoSize.text = [NSString stringWithFormat:@"%f MB",[self getfileSize:outPutPath]];
                });
            }
        }];
    }
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"start recording");
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"finish recording");
}

- (CGFloat)getfileSize:(NSString *)path
{
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSLog (@"file size: %f", (unsigned long long)[outputFileAttributes fileSize]/1024.00 /1024.00);
    return (CGFloat)[outputFileAttributes fileSize]/1024.00 /1024.00;
}

- (IBAction)flashAutoClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setFlashModeButtonStatus];
}

- (IBAction)flashOnClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
    [self setFlashModeButtonStatus];
}

- (IBAction)flashOffClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
    [self setFlashModeButtonStatus];
}

-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter     defaultCenter];
    [notificationCenter removeObserver:self];
}

-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}

/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}
/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(void(^)(AVCaptureDevice *))propertyChange{
    AVCaptureDevice *captureDevice= [self.videoCaptureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}
/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.view addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.view];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/**
 *  设置闪光灯按钮状态
 */
-(void)setFlashModeButtonStatus{
    AVCaptureDevice *captureDevice=[self.videoCaptureDeviceInput device];
    AVCaptureFlashMode flashMode=captureDevice.flashMode;
//    if([captureDevice isFlashAvailable]){
//        self.flashAutoButton.hidden=NO;
//        self.flashOnButton.hidden=NO;
//        self.flashOffButton.hidden=NO;
//        self.flashAutoButton.enabled=YES;
//        self.flashOnButton.enabled=YES;
//        self.flashOffButton.enabled=YES;
//        switch (flashMode) {
//            case AVCaptureFlashModeAuto:
//                self.flashAutoButton.enabled=NO;
//                break;
//            case AVCaptureFlashModeOn:
//                self.flashOnButton.enabled=NO;
//                break;
//            case AVCaptureFlashModeOff:
//                self.flashOffButton.enabled=NO;
//                break;
//            default:
//                break;
//        }
//    }else{
//        self.flashAutoButton.hidden=YES;
//        self.flashOnButton.hidden=YES;
//        self.flashOffButton.hidden=YES;
//    }
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
//    self.focusCursor.center=point;
//    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
//    self.focusCursor.alpha=1.0;
//    [UIView animateWithDuration:1.0 animations:^{
//        self.focusCursor.transform=CGAffineTransformIdentity;
//    } completion:^(BOOL finished) {
//        self.focusCursor.alpha=0;
//        
//    }];
}

@end
