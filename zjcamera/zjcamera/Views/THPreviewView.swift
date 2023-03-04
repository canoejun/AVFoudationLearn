//
//  THPreviewView.swift
//  zjcamera
//
//  Created by xrhan on 2023/3/3.
//

import UIKit
import AVFoundation

protocol THPreviewViewDelegate: AnyObject {
    func tappedToFocusAtPoint(point: CGPoint) //聚焦
    func tappedToExposeAtPoint(point: CGPoint) //曝光
    func tappedToResetFocusAndExposure() //点击重置聚焦&曝光
}

class THPreviewView: UIView {
    weak var delegate: THPreviewViewDelegate? = nil
    
    var tapToFocusEnabled: Bool = false
    var tapToExposeEnabled: Bool = false
    
    var focusBox = UIView()
    var exposureBox = UIView()
    var timer: Timer?
    var singleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var doubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var doubleDoubleTapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    func setup(session: AVCaptureSession) {
        guard let previewLayer = self.layer as? AVCaptureVideoPreviewLayer else {return}
        previewLayer.session = session
    }
    
    private func setupUI() {
        guard let realLayer = self.layer as? AVCaptureVideoPreviewLayer else {
            return
        }
        realLayer.videoGravity = .resizeAspectFill
        
        singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(recognizer:)))

        doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(recognizer:)))
        doubleTapRecognizer.numberOfTapsRequired = 2

        doubleDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleDoubleTap(recognizer:)))
        doubleDoubleTapRecognizer.numberOfTapsRequired = 2
        doubleDoubleTapRecognizer.numberOfTouchesRequired = 2
        
        addGestureRecognizer(singleTapRecognizer)
        addGestureRecognizer(doubleTapRecognizer)
        addGestureRecognizer(doubleDoubleTapRecognizer)

        focusBox = viewWith(color: UIColor(red: 0.102, green: 0.636, blue: 1.0, alpha: 1.0))
        exposureBox = viewWith(color: UIColor(red: 1.0, green: 0.421, blue: 0.054, alpha: 1.0))
        addSubview(focusBox)
        addSubview(exposureBox)
    }
    
    @objc private func handleSingleTap(recognizer: UIGestureRecognizer) {
        let point = recognizer.location(in: self)
        runBoxAnimationOn(view: self.focusBox, point: point)
        self.delegate?.tappedToFocusAtPoint(point: captureDevicePointFor(point: point))
    }
    
//    //私有方法 用于支持该类定义的不同触摸处理方法。 将屏幕坐标系上的触控点转换为摄像头上的坐标系点
    private func captureDevicePointFor(point: CGPoint) -> CGPoint {
        guard let realLayer = self.layer as? AVCaptureVideoPreviewLayer else {
            return .zero
        }
        return realLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    @objc private func handleDoubleTap(recognizer: UIGestureRecognizer) {
        let point = recognizer.location(in: self)
        runBoxAnimationOn(view: self.exposureBox, point: point)
        self.delegate?.tappedToExposeAtPoint(point: captureDevicePointFor(point: point))
    }
    
    @objc private func handleDoubleDoubleTap(recognizer: UIGestureRecognizer) {
        runResetAnimation()
        self.delegate?.tappedToResetFocusAndExposure()
    }
    
    private func runResetAnimation() {
        if !tapToFocusEnabled && !tapToExposeEnabled {
            return
        }
        guard let previewLayer = self.layer as? AVCaptureVideoPreviewLayer else {
            return
        }
        let centerPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: 0.5, y: 0.5))
        focusBox.center = centerPoint
        exposureBox.center = centerPoint
        exposureBox.transform = CGAffineTransformMakeScale(1.2, 1.2)
        focusBox.isHidden = false
        exposureBox.isHidden = false
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut) {
            self.focusBox.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
            self.exposureBox.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0)
        } completion: { _ in
            let delayInSeconds = 0.5
            let popTime = DispatchTime.now() + delayInSeconds
            DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
                self.focusBox.isHidden = true
                self.exposureBox.isHidden = true
                self.focusBox.transform = .identity
                self.exposureBox.transform = .identity
            })
        }

    }
    
    private func runBoxAnimationOn(view: UIView, point: CGPoint) {
        view.center = point
        view.isHidden = false
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut) {
            view.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
        } completion: { _ in
            let delayInSeconds = 0.5
            let popTime = DispatchTime.now() + delayInSeconds
            DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
                view.isHidden = true
                view.transform = .identity
            })
        }
    }
    
    private func viewWith(color: UIColor) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
        view.backgroundColor = .clear
        view.layer.borderColor = color.cgColor
        view.layer.borderWidth = 5.0
        view.isHidden = true
        return view
    }
    
}
