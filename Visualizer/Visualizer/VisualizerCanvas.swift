//
//  VisualizerCanvas.swift
//  Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subsurface
import SwiftUI

struct VisualizerCanvas: View {
    let touchData: [MTContact]
    let enablePalmRejection: Bool
    let showVelocity: Bool
    let showContactInfo: Bool

    var body: some View {
        Canvas { context, size in
            for touch in touchData {
                if enablePalmRejection, touch.finger == nil { continue }
                drawTouch(touch, in: context, size: size)
            }
        }
        .overlay(.tertiary, in: .rect(cornerRadius: 12).stroke(lineWidth: 2))
        .background(.quinary, in: .rect(cornerRadius: 12))
    }

    private func drawTouch(_ touch: MTContact, in context: GraphicsContext, size: CGSize) {
        let position = CGPoint(
            x: CGFloat(touch.normalizedVector.position.x) * size.width,
            y: (1 - CGFloat(touch.normalizedVector.position.y)) * size.height
        )

        let u = size.width / 100.0
        let dimensions = CGSize(
            width: CGFloat(touch.majorAxis) * u,
            height: CGFloat(touch.minorAxis) * u
        )

        let ellipse = makeEllipse(touch: touch, position: position, dimensions: dimensions, size: size)
        context.fill(ellipse, with: .color(.cyan.opacity(max(CGFloat(touch.pressure / 100), 0.4))))

        if showContactInfo {
            drawContactInfo(touch, at: position, height: dimensions.height, in: context)
        }

        if showVelocity {
            drawVelocityArrow(touch, at: position, canvasSize: size, in: context)
        }
    }

    private func makeEllipse(touch: MTContact, position: CGPoint, dimensions: CGSize, size: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: -0.5 * dimensions.width, y: -0.5 * dimensions.height, width: dimensions.width, height: dimensions.height))
            .rotation(.radians(Double(-touch.angle)), anchor: .topLeading)
            .offset(x: position.x, y: position.y)
            .path(in: CGRect(origin: .zero, size: size))
    }

    private func drawContactInfo(_ touch: MTContact, at position: CGPoint, height: CGFloat, in context: GraphicsContext) {
        let text = Text("""
        \(Text(touch.contactState.description).bold())
        \(touch.hand?.description ?? "Unknown") \(touch.finger?.description ?? "Unknown")
        ID \(touch.id), Pressure: \(Int(touch.pressure))
        """)
        context.draw(text, at: CGPoint(x: position.x, y: position.y - height), anchor: .bottom)
    }

    private func drawVelocityArrow(_ touch: MTContact, at position: CGPoint, canvasSize: CGSize, in context: GraphicsContext) {
        let velocity = CGSize(
            width: CGFloat(touch.normalizedVector.velocity.x / 5) * canvasSize.width,
            height: CGFloat(touch.normalizedVector.velocity.y / 5) * canvasSize.height
        )
        let velocityMag = CGFloat(hypot(touch.normalizedVector.velocity.x, touch.normalizedVector.velocity.y))

        let end = CGPoint(x: position.x + velocity.width, y: position.y - velocity.height)

        var arrow = Path()
        arrow.move(to: position)
        arrow.addLine(to: end)

        // Arrow head
        let headLength = CGFloat(4 + 16 * velocityMag)
        let headAngle = CGFloat((.pi / 10) + (.pi / 10) * velocityMag)
        let theta = atan2(end.y - position.y, end.x - position.x)

        let p1 = CGPoint(x: end.x + headLength * cos(theta + .pi - headAngle), y: end.y + headLength * sin(theta + .pi - headAngle))
        let p2 = CGPoint(x: end.x + headLength * cos(theta + .pi + headAngle), y: end.y + headLength * sin(theta + .pi + headAngle))

        arrow.move(to: end)
        arrow.addLine(to: p1)
        arrow.move(to: end)
        arrow.addLine(to: p2)

        context.stroke(arrow, with: .color(.yellow.opacity(max(velocityMag, 0.5))), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}
