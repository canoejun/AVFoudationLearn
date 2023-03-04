//
//  THOverlayView.swift
//  zjcamera
//
//  Created by xrhan on 2023/3/3.
//

import UIKit

class THOverlayView: UIView {

    @IBOutlet weak var modeView: THCameraModeView!
    @IBOutlet weak var statusView: THStatusView!
    
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if statusView.point(inside: convert(point, to: statusView), with: event)
            || modeView.point(inside: convert(point, to: modeView), with: event) {
            return true
        }
        return false
    }
}
