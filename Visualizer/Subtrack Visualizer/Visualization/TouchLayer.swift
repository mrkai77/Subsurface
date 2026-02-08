//
//  TouchLayer.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import AppKit
import Subtrack

/// Layer for rendering a single touch contact
final class TouchLayer: CALayer {
    private let ellipseLayer = CAShapeLayer()
    private let textLayer = CATextLayer()
    private var velocityLayer: VelocityLayer?

    override init() {
        super.init()

        ellipseLayer.fillColor = NSColor.cyan.cgColor
        addSublayer(ellipseLayer)

        textLayer.fontSize = 10
        textLayer.foregroundColor = NSColor.labelColor.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        addSublayer(textLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(contact: MTContact, canvasSize: CGSize, showContactInfo: Bool, showVelocity: Bool) {
        let u = canvasSize.width / 100.0

        let x = CGFloat(contact.normalizedVector.position.x) * canvasSize.width
        let y = CGFloat(contact.normalizedVector.position.y) * canvasSize.height

        let w = CGFloat(contact.majorAxis) * u
        let h = CGFloat(contact.minorAxis) * u

        // Update ellipse path only if size changed
        let ellipseRect = CGRect(x: -w * 0.5, y: -h * 0.5, width: w, height: h)
        if ellipseLayer.path == nil || ellipseLayer.bounds.size != ellipseRect.size {
            ellipseLayer.path = CGPath(ellipseIn: ellipseRect, transform: nil)
            ellipseLayer.bounds = ellipseRect
        }

        // Use layer transforms for position and rotation (GPU-accelerated)
        ellipseLayer.position = CGPoint(x: x, y: y)
        ellipseLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(contact.angle)))

        ellipseLayer.fillColor = NSColor.systemBlue.withAlphaComponent(
            max(CGFloat(contact.pressure / 100), 0.4)
        ).cgColor

        // Contact info text
        if showContactInfo {
            textLayer.isHidden = false
            let hand = contact.hand?.description ?? "Unknown"
            let finger = contact.finger?.description ?? "Unknown"
            textLayer.string = "\(contact.contactState.description)\n\(hand) \(finger)\nID \(contact.id)"

            let textSize = CGSize(width: 100, height: 40)
            textLayer.frame = CGRect(
                x: x - textSize.width * 0.5,
                y: y - h * 0.5 - textSize.height,
                width: textSize.width,
                height: textSize.height
            )
        } else {
            textLayer.isHidden = true
        }

        // Velocity arrow
        if showVelocity {
            if velocityLayer == nil {
                let newVelocityLayer = VelocityLayer()
                velocityLayer = newVelocityLayer
                addSublayer(newVelocityLayer)
            }
            velocityLayer?.update(contact: contact, canvasSize: canvasSize)
        } else {
            velocityLayer?.removeFromSuperlayer()
            velocityLayer = nil
        }
    }
}
