//
//  THCameraController.swift
//  zjcamera
//
//  Created by xrhan on 2023/3/3.
//

import AVFoundation
import UIKit
import Photos
import AssetsLibrary

protocol THCameraControllerDelegate: AnyObject {
    // 1发生错误事件是，需要在对象委托上调用一些方法来处理
    func deviceConfigurationFailedWithError(error: Error?)
    func mediaCaptureFailedWithError(error: Error?)
    func assetLibraryWriteFailedWithError(error: Error?)
}

class THCameraController: NSObject, AVCapturePhotoCaptureDelegate {
    weak var delegate: THCameraControllerDelegate? = nil
    
    private(set) var captureSession: AVCaptureSession = AVCaptureSession()
    private var activeVideoInput: AVCaptureDeviceInput? {
        didSet {
            //询问激活中的摄像头是否支持兴趣点对焦
            cameraSupportsTapToFocus = activeVideoInput?.device.isFocusPointOfInterestSupported ?? false
            cameraSupportsTapToExpose = activeVideoInput?.device.isExposurePointOfInterestSupported ?? false
            cameraHasTorch = activeVideoInput?.device.hasTorch ?? false
            cameraHasFlash = activeVideoInput?.device.hasFlash ?? false
        }
    }
    private var imageOutput: AVCapturePhotoOutput?
    private let photoSetting = AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg])
    private var movieOuputPath = URL(string: "")
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoQueue: DispatchQueue = DispatchQueue(label: "cc.VideoQueue")
    
    override init() {
        super.init()
    }

    
    func setupSession() -> Bool {
        //设置图像的分辨率
        self.captureSession.sessionPreset = .high
        
        //拿到默认视频捕捉设备 iOS系统返回后置摄像头
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            return false
        }
        //选择默认音频捕捉设备 即返回一个内置麦克风
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            return false
        }
        
        //将捕捉设备封装成AVCaptureDeviceInput
        //注意：为会话添加捕捉设备，必须将设备封装成AVCaptureDeviceInput对象
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            //canAddInput：测试是否能被添加到会话中
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                activeVideoInput = videoInput
            } else {
                return false
            }

            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            } else {
                return false
            }
        } catch {
            print("--canoe--error\(error)")
            return false
        }
        
        imageOutput = AVCapturePhotoOutput()
        imageOutput?.photoSettingsForSceneMonitoring = photoSetting
        if captureSession.canAddOutput(imageOutput ?? AVCapturePhotoOutput()) {
            captureSession.addOutput(imageOutput ?? AVCapturePhotoOutput())
        }
        
        movieOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(movieOutput ?? AVCaptureMovieFileOutput()) {
            captureSession.addOutput(movieOutput ?? AVCaptureMovieFileOutput())
        }
        
         return true
    }

    func startSession() {
        if captureSession.isRunning {
            return
        }
        videoQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if !captureSession.isRunning {
            return
        }
        videoQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    // 3 切换不同的摄像头
    func switchCameras() -> Bool {
        guard canSwitchCameras(),
              let unwrappedActiveVideoInput = activeVideoInput,
              let inactiveDevice = inactiveCamera() else { return false }
        do {
            let videoInput = try AVCaptureDeviceInput(device: inactiveDevice)
            captureSession.beginConfiguration()
            captureSession.removeInput(unwrappedActiveVideoInput)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                activeVideoInput = videoInput
            } else {
                captureSession.addInput(unwrappedActiveVideoInput)
            }
            captureSession.commitConfiguration()
        } catch {
            print(error)
            self.delegate?.deviceConfigurationFailedWithError(error: error)
            return false
        }
        
        return true
    }
    
    func canSwitchCameras() -> Bool {
        return cameraCount > 1
    }
    
    var cameraCount: Int {
        get {
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices.count
        }
    }
    private(set) var cameraHasTorch: Bool = false//手电筒
    private(set) var cameraHasFlash: Bool = false //闪光灯
    private(set) var cameraSupportsTapToFocus: Bool = false
    private(set) var cameraSupportsTapToExpose: Bool = false
    
    var torchMode: AVCaptureDevice.TorchMode = .off
    var flashMode: AVCaptureDevice.FlashMode = .off
    
    // 4 聚焦、曝光、重设聚焦、曝光的方法
    func focusAtPoint(point: CGPoint) {
        guard let activeDevice = activeCamera(),
              activeDevice.isFocusPointOfInterestSupported, //是否支持兴趣点对焦 & 是否自动对焦模式
              activeDevice.isFocusModeSupported(.autoFocus) else {return}
        do {
            //锁定设备准备配置，如果获得了锁
            try activeDevice.lockForConfiguration()
            activeDevice.focusPointOfInterest = point
            activeDevice.focusMode = .autoFocus
            activeDevice.unlockForConfiguration()
        } catch {
            print(error)
            self.delegate?.deviceConfigurationFailedWithError(error: error)
        }
    }
    func exposeAtPoint(point: CGPoint) {
        guard let activeDevice = activeCamera(),
              activeDevice.isExposurePointOfInterestSupported, //是否支持兴趣点对焦 & 是否自动对焦模式
              activeDevice.isExposureModeSupported(.autoExpose) else {return}
        do {
            //锁定设备准备配置，如果获得了锁
            try activeDevice.lockForConfiguration()
            activeDevice.exposurePointOfInterest = point
            activeDevice.exposureMode = .autoExpose
            //判断设备是否支持锁定曝光的模式
//            if activeDevice.isExposureModeSupported(.locked) {
//                activeDevice.addObserver(self, forKeyPath: "adjustingExposure", context: UnsafeMutableRawPointer)
//            }
            activeDevice.unlockForConfiguration()
        } catch {
            print(error)
            self.delegate?.deviceConfigurationFailedWithError(error: error)
        }
    }
    func resetFocusAndExposureModes() {
        
    }

}

//MARK: 配置摄像头支持的方法
extension THCameraController {
    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        //获取可用视频设备
        let videoDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices
        return videoDevices.first
    }
    
    func activeCamera() -> AVCaptureDevice? {
        return activeVideoInput?.device
    }
    
    //返回当前未激活的摄像头
    func inactiveCamera() -> AVCaptureDevice? {
        //通过查找当前激活摄像头的反向摄像头获得，如果设备只有1个摄像头，则返回nil
        var device: AVCaptureDevice?
        if self.cameraCount > 1 {
            if let activePosition = activeCamera()?.position {
                device = cameraWithPosition(position: activePosition == .front ? .back : .front)
            }
        }
        return device
    }
    
    //设置是否打开手电筒
    func setTorchMode(mode: AVCaptureDevice.TorchMode) {
        guard let unwrappedActiveDevice = activeCamera() else {return}
        if unwrappedActiveDevice.isTorchModeSupported(mode) {
            do {
                try unwrappedActiveDevice.lockForConfiguration()
                unwrappedActiveDevice.torchMode = mode
                unwrappedActiveDevice.unlockForConfiguration()
            } catch {
                print(error)
                self.delegate?.deviceConfigurationFailedWithError(error: error)
            }
        }
    }
    
    func setFlashMode(mode: AVCaptureDevice.FlashMode) {
        guard let unwrappedActiveDevice = activeCamera() else {return}
        
        if unwrappedActiveDevice.isFlashModeSupported(mode) {
            do {
                try unwrappedActiveDevice.lockForConfiguration()
                unwrappedActiveDevice.flashMode = mode
                unwrappedActiveDevice.unlockForConfiguration()
            } catch {
                print(error)
                self.delegate?.deviceConfigurationFailedWithError(error: error)
            }
        }
    }

}

extension THCameraController {
    // 5 实现捕捉静态图片 & 视频的功能
    //捕捉静态图片
    func captureStillImage() {
        //获取链接
        guard let connection = imageOutput?.connection(with: .video) else {return}
        //程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
        //判断是否支持设置视频方向
        if connection.isVideoOrientationSupported {
            //获取方向值
            connection.videoOrientation = videoOrientation()
        }
        let setting = AVCapturePhotoSettings(from: photoSetting)
        if setting.availablePreviewPhotoPixelFormatTypes.count > 0 {
            setting.previewPhotoFormat =  [
                kCVPixelBufferPixelFormatTypeKey : setting.availablePreviewPhotoPixelFormatTypes.first!,
                kCVPixelBufferWidthKey : 512,
                kCVPixelBufferHeightKey : 512
            ] as [String: Any]
        }
        
        imageOutput?.capturePhoto(with: setting, delegate: self)
    }
    
    private func videoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation = .portrait
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .portrait
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        case .landscapeRight:
            orientation = .landscapeLeft
        default:
            orientation = .landscapeRight
        }
        return orientation
    }
    //视频录制
    //开始录制
    func startRecording() {
        guard !isRecording() else {return}
        guard let connection = self.movieOutput?.connection(with: .video),
              let activeDev = activeCamera() else {return}
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation()
        }
        //判断是否支持视频稳定 可以显著提高视频的质量。只会在录制视频文件涉及
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
//        摄像头可以进行平滑对焦模式操作。即减慢摄像头镜头对焦速度。当用户移动拍摄时摄像头会尝试快速自动对焦。
        if activeDev.isSmoothAutoFocusSupported {
            do {
                try activeDev.lockForConfiguration()
                activeDev.isSmoothAutoFocusEnabled = true
                activeDev.unlockForConfiguration()
            } catch {
                print(error)
                self.delegate?.deviceConfigurationFailedWithError(error: error)
            }
        }
        self.movieOuputPath = uniqueURL()
        if let path = movieOuputPath {
            movieOutput?.startRecording(to: path, recordingDelegate: self)
        }
        
    }

    //停止录制
    func stopRecording() {
        if isRecording() {
            movieOutput?.stopRecording()
        }
    }

    //获取录制状态
    func isRecording() -> Bool {
        return movieOutput?.isRecording ?? false
    }

    //录制时间
    func recordedDuration() -> CMTime {
        return movieOutput?.recordedDuration ?? CMTime()
    }
    
    //写入视频唯一文件系统URL
    private func uniqueURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory().appending("output.mov"))
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let cgImage = photo.cgImageRepresentation(), let pre = photo.previewCGImageRepresentation() {
            let ori = UIImage.getUIImageOrientationFromDevice()
            writeImageToAssetsLibrary(image: UIImage(cgImage: cgImage, scale: 1.0, orientation: ori),
                                      preImg: UIImage(cgImage: pre, scale: 1.0, orientation: ori))
        }
    }
    
    
    private func writeImageToAssetsLibrary(image: UIImage,preImg: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            
        } completionHandler: { [weak self] success, error in
            if success {
                self?.postThumbnailNotifification(image: preImg)
            } else {
                print(error ?? "write image error")
                self?.delegate?.assetLibraryWriteFailedWithError(error: error)
            }
        }

    }
    
    //发送缩略图通知
    private func postThumbnailNotifification(image: UIImage) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "THThumbnailCreatedNotification"), object: image)
        }
    }
}

extension THCameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            print(error ?? "error fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo output ")
            self.delegate?.mediaCaptureFailedWithError(error: error!)
            return
        }
        writeVideoToAssetsLibrary(videoPath: movieOuputPath)
    }
    
    private func writeVideoToAssetsLibrary(videoPath: URL?) {
        guard let unwrappedvideoPath = videoPath else {return}
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: unwrappedvideoPath)
        } completionHandler: { [weak self] success, error in
            if success {
                self?.generateThumbnailForVideo(at: unwrappedvideoPath)
            } else {
                print(error ?? "write video error")
                self?.delegate?.assetLibraryWriteFailedWithError(error: error)
            }
        }
    }
    
    //获取视频左下角缩略图
    private func generateThumbnailForVideo(at videoUrl: URL) {
        videoQueue.async { [weak self] in
            let asset = AVAsset(url: videoUrl)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            //设置maximumSize 宽为100，高为0 根据视频的宽高比来计算图片的高度
            imageGenerator.maximumSize = CGSize(width: 100, height: 0)
//            捕捉视频缩略图会考虑视频的变化（如视频的方向变化），如果不设置，缩略图的方向可能出错
            imageGenerator.appliesPreferredTrackTransform = true
            if let cgImg = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) {
                self?.postThumbnailNotifification(image: UIImage(cgImage: cgImg))
            }
        }
    }
    
}

extension UIImage {
    static func getUIImageOrientationFromDevice() -> UIImage.Orientation {
        let deviceOri = UIDevice.current.orientation
        var imgOri = UIImage.Orientation.up
        switch (deviceOri) {
        case .portrait,.faceUp,.unknown:
            imgOri = .right
        case .portraitUpsideDown,.faceDown:
            imgOri = .left
        case .landscapeLeft:
            imgOri = .up
        case .landscapeRight:
            imgOri = .down
        default:
            imgOri = .up
        }
        print("getUIImageOrientationFromDevice-device:\(deviceOri.rawValue)- img:\(imgOri.rawValue)")
        return imgOri
    }
}
