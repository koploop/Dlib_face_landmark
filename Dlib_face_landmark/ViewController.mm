//
//  ViewController.m
//  Dlib_face_landmark
//
//  Created by LVHAN on 2018/9/7.
//  Copyright © 2018年 Koploop. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <opencv2/imgproc/types_c.h>
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/imgcodecs/ios.h>
#import "FaceDlibWrapper.h"

@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) UIImageView *cameraView;
@property (nonatomic,strong) dispatch_queue_t sample;
@property (nonatomic,strong) dispatch_queue_t faceQueue;
@property (nonatomic, strong) FaceDlibWrapper *faceWrapper;

@property (nonatomic,copy) NSArray *currentMetadata; //?< 如果检测到了人脸系统会返回一个数组 我们将这个数组存起来

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _currentMetadata = [NSMutableArray arrayWithCapacity:0];
    
    [self.view addSubview: self.cameraView];
    
    _sample = dispatch_queue_create("sample", NULL);
    _faceQueue = dispatch_queue_create("face", NULL);
    
//    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
//    AVCaptureDevice *deviceF;
//    for (AVCaptureDevice *device in devices ) {
//        if (device.position == AVCaptureDevicePositionFront ) {
//            deviceF = device;
//            break;
//        }
//    }
    AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                           mediaType:AVMediaTypeVideo
                                                            position:AVCaptureDevicePositionFront];
    AVCaptureDevice *deviceF;
    NSArray *devices = deviceSession.devices;
    if (devices.count) {
        deviceF = devices.firstObject;
    }
    
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:deviceF error:nil];
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    
    [output setSampleBufferDelegate:self queue:_sample];
    
    AVCaptureMetadataOutput *metaout = [[AVCaptureMetadataOutput alloc] init];
    [metaout setMetadataObjectsDelegate:self queue:_faceQueue];
    self.session = [[AVCaptureSession alloc] init];
    
    [self.session beginConfiguration];
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }
    
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    }
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
    }
    
    if ([self.session canAddOutput:metaout]) {
        [self.session addOutput:metaout];
    }
    [self.session commitConfiguration];
    
    NSString     *key           = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber     *value         = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    [output setVideoSettings:videoSettings];
    
    //这里 我们告诉要检测到人脸 就给我一些反应，里面还有QRCode 等 都可以放进去，就是 如果视频流检测到了你要的 就会出发下面第二个代理方法
    [metaout setMetadataObjectTypes:@[AVMetadataObjectTypeFace]];
    
    AVCaptureSession* session = (AVCaptureSession *)self.session;
    //前置摄像头一定要设置一下 要不然画面是镜像
    for (AVCaptureVideoDataOutput* output in session.outputs) {
        for (AVCaptureConnection * av in output.connections) {
            //判断是否是前置摄像头状态
            if (av.supportsVideoMirroring) {
                //镜像设置
                av.videoOrientation = AVCaptureVideoOrientationPortrait;
                av.videoMirrored = YES;
            }
        }
    }
    [self.session startRunning];
    
}
#pragma mark - AVCaptureSession Delegate -
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSMutableArray *bounds = [NSMutableArray arrayWithCapacity:0];
    for (AVMetadataFaceObject *faceobject in self.currentMetadata) {
        AVMetadataObject *face = [output transformedMetadataObjectForMetadataObject:faceobject connection:connection];
        [bounds addObject:[NSValue valueWithCGRect:face.bounds]];
    }
    
    UIImage *image = [self imageFromPixelBuffer:sampleBuffer];
    cv::Mat mat;
    UIImageToMat(image, mat);
    
    //获取关键点，将脸部信息的数组 和 相机流 传进去
    NSArray *facesLandmarks = [self.faceWrapper detecitonOnSampleBuffer:sampleBuffer inRects:bounds];
    
    // 绘制68 个关键点
    for (NSArray *landmarks in facesLandmarks) {
        for (NSValue *point in landmarks) {
            CGPoint p = [point CGPointValue];
            cv::rectangle(mat, cv::Rect(p.x,p.y,4,4), cv::Scalar(255,0,0,255),-1);
        }
    }
    for (NSValue *rect in bounds) {
        CGRect r = [rect CGRectValue];
        //画框
        cv::rectangle(mat, cv::Rect(r.origin.x,r.origin.y,r.size.width,r.size.height), cv::Scalar(255,0,0,255));
        
    }
    
    //这里不考虑性能 直接怼Image
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cameraView.image = MatToUIImage(mat);
    });
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    //当检测到了人脸会走这个回调
    _currentMetadata = metadataObjects;
}

- (UIImage*)imageFromPixelBuffer:(CMSampleBufferRef)p
{
    CVImageBufferRef buffer;
    buffer = CMSampleBufferGetImageBuffer(p);
    
    CVPixelBufferLockBaseAddress(buffer, 0);
    uint8_t *base;
    size_t width, height, bytesPerRow;
    base = (uint8_t *)CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    CGColorSpaceRef colorSpace;
    CGContextRef cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef cgImage;
    UIImage *image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return image;
}

- (UIImageView *)cameraView
{
    if (!_cameraView) {
        _cameraView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        //不拉伸
        _cameraView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _cameraView;
}

- (FaceDlibWrapper *)faceWrapper {
    if (!_faceWrapper) {
        _faceWrapper = [[FaceDlibWrapper alloc] init];
    }
    return _faceWrapper;
}

@end

