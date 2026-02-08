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

    func update(contact: MTContact, canvasSize: CGSize, showContactInfo: Bool) {
        let u = canvasSize.width / 100.0

        let x = CGFloat(contact.normalizedVector.position.x) * canvasSize.width
        let y = CGFloat(contact.normalizedVector.position.y) * canvasSize.height

        let w = CGFloat(contact.majorAxis) * u
        let h = CGFloat(contact.minorAxis) * u

        // Create ellipse path
        let rect = CGRect(x: x - w * 0.5, y: y - h * 0.5, width: w, height: h)
        let path = CGMutablePath()

        // Apply rotation transform
        let transform = CGAffineTransform(translationX: x, y: y)
            .rotated(by: CGFloat(contact.angle))
            .translatedBy(x: -x, y: -y)

        path.addEllipse(in: rect, transform: transform)

        ellipseLayer.path = path
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
    }
}
