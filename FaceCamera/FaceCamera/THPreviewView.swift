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
        previewLayer.session = session
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private var faceLayers: [Int: CALayer] = [:]
    private let operationLayer: CALayer = CALayer()
    private var previewLayer: AVCaptureVideoPreviewLayer {
        get {
            return self.layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    private func setupUI() {
        previewLayer.videoGravity = .resizeAspectFill
        operationLayer.frame = self.bounds
        operationLayer.sublayerTransform = CATransform3D.perspective(eyePosition: 1000)
        previewLayer.addSublayer(operationLayer)
    }
}

extension CATransform3D {
    static func perspective(eyePosition: CGFloat) -> CATransform3D {
        //CATransform3D 图层的旋转，缩放，偏移，歪斜和应用的透
        //CATransform3DIdentity是单位矩阵，该矩阵没有缩放，旋转，歪斜，透视。该矩阵应用到图层上，就是设置默认值。
        var transform: CATransform3D = CATransform3DIdentity
        //透视效果（就是近大远小），是通过设置m34 m34 = -1.0/D 默认是0.D越小透视效果越明显
        //D:eyePosition 观察者到投射面的距离
        transform.m34 = -1.0/eyePosition
        return transform
    }
}

extension THPreviewView: THFaceDetectionDelegate {
    //将检测到的人脸进行可视化
    func didDetectFaces(_ faces: [AVMetadataObject]) {
        //创建一个本地数组 保存转换后的人脸数据
        let transformedFaces = faces.map { obj in
            //将摄像头的人脸数据 转换为 视图上的可展示的数据
            //简单说：UIKit的坐标 与 摄像头坐标系统（0，0）-（1，1）不一样。所以需要转换
            //转换需要考虑图层、镜像、视频重力、方向等因素 在iOS6.0之前需要开发者自己计算，但iOS6.0后提供方法
            return previewLayer.transformedMetadataObject(for: obj)
        }
        
        //获取faceLayers的key，用于确定哪些人移除了视图并将对应的图层移出界面。
        /*
            支持同时识别10个人脸
         */
        var lostFaces = Array(faceLayers.keys)
        //遍历每个转换的人脸对象
        for item in transformedFaces {
            guard let realItem = item as? AVMetadataFaceObject else {continue}
            let faceId = realItem.faceID
            lostFaces.removeAll(where: {$0 == faceId})
            var faceLayer: CALayer
            if faceLayers[faceId] != nil {
                faceLayer = faceLayers[faceId]!
            } else {
                faceLayer = makeLayer()
                operationLayer.addSublayer(faceLayer)
                faceLayers[faceId] = faceLayer
            }
            //设置图层的transform属性 CATransform3DIdentity 图层默认变化 这样可以重新设置之前应用的变化
            faceLayer.transform = CATransform3DIdentity
            faceLayer.frame = realItem.bounds
            
            //判断人脸对象是否具有有效的斜倾交。
            if realItem.hasRollAngle {
                let t = transformForRollAngle(rollAngleInDegrees: realItem.rollAngle)
                faceLayer.transform = CATransform3DConcat(faceLayer.transform, t)
            }
            //判断人脸对象是否具有有效的偏转角
            if realItem.hasYawAngle {
                let t = transformForYawAngle(yawAngleInDegrees: realItem.yawAngle)
                faceLayer.transform = CATransform3DConcat(faceLayer.transform, t)
            }
        }
        
        for item in lostFaces {
            let lostlayer = faceLayers.removeValue(forKey: item)
            lostlayer?.removeFromSuperlayer()
        }
    }
    
    private func makeLayer() -> CALayer {
        let layer = CALayer()
        layer.borderWidth = 5.0
        layer.borderColor = UIColor.orange.cgColor
        layer.contents = UIImage(named: "551.png")
        return layer
    }
    
    //将 RollAngle 的 rollAngleInDegrees 值转换为 CATransform3D
    private func transformForRollAngle(rollAngleInDegrees: CGFloat) -> CATransform3D {
        //将人脸对象得到的RollAngle 单位“度” 转为Core Animation需要的弧度值
        let rollAngleInRadians = rollAngleInDegrees * .pi / 180.0
        //将结果赋给CATransform3DMakeRotation x,y,z轴为0，0，1 得到绕Z轴倾斜角旋转转换
        return CATransform3DMakeRotation(rollAngleInRadians, 0, 0, 1)
    }
    
    //将 YawAngle 的 yawAngleInDegrees 值转换为 CATransform3D
    private func transformForYawAngle(yawAngleInDegrees: CGFloat) -> CATransform3D {
        //将人脸对象得到 单位“度” 转为Core Animation需要的弧度值
        let yawAngleInRaians = yawAngleInDegrees * .pi / 180.0
        //将结果CATransform3DMakeRotation x,y,z轴为0，-1，0 得到绕Y轴选择。
        //由于overlayer 需要应用sublayerTransform，所以图层会投射到z轴上，人脸从一侧转向另一侧会有3D 效果
        let yawTransform = CATransform3DMakeRotation(yawAngleInRaians, 0, -1, 0)
        //因为应用程序的界面固定为垂直方向，但需要为设备方向计算一个相应的旋转变换
        //如果不这样，会造成人脸图层的偏转效果不正确
        return CATransform3DConcat(yawTransform, orientationTransform())
    }
    
    private func orientationTransform() -> CATransform3D{
        var angle = 0.0
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            angle = .pi
        case .landscapeLeft:
            angle = .pi * 0.5
        case .landscapeRight:
            angle = -.pi * 0.5
        default:
            angle = 0.0
        }
        
        return CATransform3DMakeRotation(angle, 0, 0, 1)
    }
}
