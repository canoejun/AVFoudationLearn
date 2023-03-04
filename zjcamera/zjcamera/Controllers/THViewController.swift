//
//  THViewController.swift
//  zjcamera
//
//  Created by xrhan on 2023/3/3.
//

import UIKit
import CoreMedia

class THViewController: UIViewController, THPreviewViewDelegate {

    @IBOutlet weak var previewView: THPreviewView!
    
    @IBOutlet weak var overlayView: THOverlayView!
    
    @IBOutlet weak var thumbnailButton: UIButton!
    
    private var timer = Timer()
    
    private var cameraController: THCameraController = THCameraController()
    private var cameraModel: THCameraMode = .photo
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(updateThumbnail(notify:)), name: NSNotification.Name(rawValue: "THThumbnailCreatedNotification"), object: nil)
        cameraModel = .video
        if self.cameraController.setupSession() {
            previewView .setup(session: cameraController.captureSession)
            previewView.delegate = self
            cameraController.startSession()
        } else {
            print("--canoe cameraController setupsession fail")
        }
        
        previewView.tapToFocusEnabled = cameraController.cameraSupportsTapToFocus
        previewView.tapToExposeEnabled = cameraController.cameraSupportsTapToExpose
    }
    
    @objc private func updateThumbnail(notify: Notification) {
        guard let image = notify.object as? UIImage else {return}
        thumbnailButton.setBackgroundImage(image, for: .normal)
        thumbnailButton.layer.borderColor = UIColor.white.cgColor
        thumbnailButton.layer.borderWidth = 1.0
    }
    
    @IBAction func captureOrRecord(_ sender: UIButton) {
        if cameraModel == .photo {
            cameraController.captureStillImage()
        } else {
            if cameraController.isRecording() {
                cameraController.stopRecording()
                stopTimer()
            } else {
                DispatchQueue(label: "com.tapharmonic.kamera").async {
                    self.cameraController.startRecording()
                    self.startTimer()
                }
            }
            sender.isSelected = !sender.isSelected
        }
        
    }
    
    @IBAction func cameraModeChanged(_ sender: THCameraModeView) {
        cameraModel = sender.cameraMode
    }
    
    @IBAction func switchCamera(_ sender: Any) {
        if cameraController.switchCameras() {
            var hidden = false
            if cameraModel == .photo {
                hidden = !cameraController.cameraHasFlash
            } else {
                hidden = !cameraController.cameraHasTorch
            }
            overlayView.statusView.flashControl.isHidden = hidden
            previewView.tapToExposeEnabled = cameraController.cameraSupportsTapToExpose
            previewView.tapToFocusEnabled = cameraController.cameraSupportsTapToFocus
            cameraController.resetFocusAndExposureModes()
        }
    }
    
    private func startTimer() {
        self.timer.invalidate()
        timer = Timer(timeInterval: 0.5, repeats: true, block: { [weak self] _ in
            guard let `self` = self else {return}
            let duration = self.cameraController.recordedDuration()
            let time = CMTimeGetSeconds(duration)
            let hours = Int(time / 3600)
            let minutes = Int((time / 60).truncatingRemainder(dividingBy: 60))
            let seconds = Int(time.truncatingRemainder(dividingBy: 60))
            print(duration,time,hours,minutes,seconds)
            self.overlayView.statusView.elapsedTimeLabel.text = String(format: "%02d:%02d:%02d", hours,minutes,seconds)
        })
        RunLoop.main.add(timer, forMode: .common)
    }
    private func stopTimer() {
        self.timer.invalidate()
        self.overlayView.statusView.elapsedTimeLabel.text = "00:00:00"
    }
//        [self.timer invalidate];
//        self.timer = [NSTimer timerWithTimeInterval:0.5
//                                             target:self
//                                           selector:@selector(updateTimeDisplay)
//                                           userInfo:nil
//                                            repeats:YES];
//        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
//    }
}

extension THPreviewViewDelegate {
    func tappedToFocusAtPoint(point: CGPoint) {
        
    }
    
    func tappedToExposeAtPoint(point: CGPoint) {
        
    }
    
    func tappedToResetFocusAndExposure() {
        
    }
}
