//
//  VelocityLayer.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import AppKit
import Subtrack

/// Layer for rendering velocity arrow
final class VelocityLayer: CALayer {
    private let arrowLayer = CAShapeLayer()

    override init() {
        super.init()

        arrowLayer.strokeColor = NSColor.yellow.cgColor
        arrowLayer.lineWidth = 4
        arrowLayer.lineCap = .round
        arrowLayer.lineJoin = .round
        arrowLayer.fillColor = nil
        addSublayer(arrowLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(contact: MTContact, canvasSize: CGSize) {
        let x = CGFloat(contact.normalizedVector.position.x) * canvasSize.width
        let y = CGFloat(contact.normalizedVector.position.y) * canvasSize.height

        let velocity = CGSize(
            width: CGFloat(contact.normalizedVector.velocity.x / 5) * canvasSize.width,
            height: CGFloat(contact.normalizedVector.velocity.y / 5) * canvasSize.height
        )
        let velocityMag = CGFloat(
            hypot(contact.normalizedVector.velocity.x, contact.normalizedVector.velocity.y)
        )

        let start = CGPoint(x: x, y: y)
        let end = CGPoint(x: x + velocity.width, y: y + velocity.height)

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        // Arrow head
        let headLength = CGFloat(4 + 16 * velocityMag)
        let headAngle = CGFloat((.pi / 10) + (.pi / 10) * velocityMag)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let theta = atan2(dy, dx)

        let a1 = theta + .pi - headAngle
        let a2 = theta + .pi + headAngle

        let p1 = CGPoint(x: end.x + headLength * cos(a1), y: end.y + headLength * sin(a1))
        let p2 = CGPoint(x: end.x + headLength * cos(a2), y: end.y + headLength * sin(a2))

        path.move(to: end)
        path.addLine(to: p1)
        path.move(to: end)
        path.addLine(to: p2)

        arrowLayer.path = path
        arrowLayer.strokeColor = NSColor.yellow.withAlphaComponent(
            max(velocityMag, 0.5)
        ).cgColor
    }
}
