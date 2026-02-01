//
//  ContentView.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                if viewModel.isListening {
                    Button {
                        viewModel.stop()
                    } label: {
                        Text("Stop")
                    }
                } else {
                    Button {
                        viewModel.start()
                    } label: {
                        Text("Start")
                    }
                }
            }

            Canvas { context, size in
                for touch in viewModel.touchData {
                    let content = makeContent(touch: touch, size: size)

                    context.fill(
                        content.ellipse,
                        with: .color(.cyan.opacity(Double(min(touch.totalCapacitance, 0.75))))
                    )

                    context.stroke(content.line, with: .color(.cyan), lineWidth: 2)

                    context.draw(content.text, at: content.center, anchor: .center)
                }
            }
            .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
            .overlay(.tertiary, in: .rect(cornerRadius: 12).stroke(lineWidth: 2))
            .background(.quinary, in: .rect(cornerRadius: 12))
        }
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private func makeContent(touch: MTContact, size: CGSize) -> (
        ellipse: Path,
        line: Path,
        text: Text,
        center: CGPoint
    ) {
        let x = Double(touch.normalizedVector.position.x) * size.width
        let y = Double(1.0 - touch.normalizedVector.position.y) * size.height

        let xVel = Double(touch.normalizedVector.velocity.x / 5) * size.width
        let yVel = Double(touch.normalizedVector.velocity.y / 5) * size.height

        let u = size.width / 100.0
        let w = Double(touch.majorAxis) * u
        let h = Double(touch.minorAxis) * u

        let ellipse = Path(ellipseIn: CGRect(x: -0.5 * w, y: -0.5 * h, width: w, height: h))
            .rotation(.radians(Double(-touch.angle)), anchor: .topLeading)
            .offset(x: x, y: y)
            .path(in: CGRect(origin: .zero, size: size))

        let line = Path { path in
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + xVel, y: y - yVel))
        }

        let state = Text(touch.contactState.description)
            .bold()
        let finger = Text("\(touch.hand?.description ?? "Unknwon") \(touch.finger?.description ?? "Unknown") Finger")
            .font(.caption)
        let id = Text("ID \(touch.id)")
            .font(.caption2)

        let text = Text("\(state)\n\(finger)\n\(id)")

        return (ellipse, line, text, CGPoint(x: x, y: y - 35))
    }
}
