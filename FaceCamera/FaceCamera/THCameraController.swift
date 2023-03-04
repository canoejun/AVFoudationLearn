//
//  THCameraController.swift
//  FaceCamera
//
//  Created by xrhan on 2023/3/4.
//

import UIKit

class THCameraController: THBaseCameraController {
    @objc weak var faceDetectionDelegate: THFaceDetectionDelegate? = nil
    
    private var metaDataOutput = AVCaptureMetadataOutput()
    
    override func setupSessionOutputs() throws {
        if captureSession.canAddOutput(metaDataOutput) {
            captureSession.addOutput(metaDataOutput)
            
            //设置metadataObjectTypes 指定对象输出的元数据类型。
            /*
             限制检查到元数据类型集合的做法是一种优化处理方法。可以减少我们实际感兴趣的对象数量
             支持多种元数据。这里只保留对人脸元数据感兴趣
             */
            metaDataOutput.metadataObjectTypes = [.face]
            
            //创建主队列： 因为人脸检测用到了硬件加速，而且许多重要的任务都在主线程中执行，所以需要为这次参数指定主队列。
            let mainQueue = DispatchQueue.main
            //通过设置AVCaptureVideoDataOutput的代理，就能获取捕获到一帧一帧数据
            metaDataOutput.setMetadataObjectsDelegate(self, queue: mainQueue)
        }
        
    }
}

extension THCameraController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
//        for objc in metadataObjects {
//            if let faceObj = objc as? AVMetadataFaceObject {
//                print("--",faceObj.faceID,faceObj.bounds)
//            }
//        }
        self.faceDetectionDelegate?.didDetectFaces(metadataObjects)
        
    }
}
