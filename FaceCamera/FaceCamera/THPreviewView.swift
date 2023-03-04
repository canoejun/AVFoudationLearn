//
//  THPreviewView.swift
//  FaceCamera
//
//  Created by xrhan on 2023/3/4.
//

import UIKit

class THPreviewView: UIView {
    
    override class var layerClass: AnyClass {
        get {
            return AVCaptureVideoPreviewLayer.self
        }
    }
    
    
    @objc func setSession(session: AVCaptureSession) {
        guard let preViewLayer = self.layer as? AVCaptureVideoPreviewLayer else {
            return
        }
        preViewLayer.session = session
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
    }

}

extension THPreviewView: THFaceDetectionDelegate {
    func didDetectFaces(_ faces: [Any]!) {
        
    }
    
}
