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
            
            GeometryReader { proxy in
                ForEach(viewModel.touchData) { touch in
                    view(for: touch, size: proxy.size)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.smooth(duration: 0.4)),
                                removal: .opacity.animation(.smooth(duration: 0.2))
                            )
                        )
                }
            }
            .animation(.smooth(duration: 0.2), value: viewModel.touchData)
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

    private func view(for touch: MTContact, size parentSize: CGSize) -> some View {
        let u = parentSize.width / 100.0
        let origin = CGPoint(
            x: CGFloat(touch.normalizedVector.position.x) * parentSize.width,
            y: (1 - CGFloat(touch.normalizedVector.position.y)) * parentSize.height
        )
        let size = CGSize(
            width: max(CGFloat(touch.majorAxis) * u, 5 * u),
            height: max(CGFloat(touch.minorAxis) * u, 5 * u)
        )
        let velocity = CGSize(
            width: CGFloat(touch.normalizedVector.velocity.x / 5) * parentSize.width,
            height: CGFloat(touch.normalizedVector.velocity.y / 5) * parentSize.height
        )
        let velocityMag = CGFloat(
            hypot(
                touch.normalizedVector.velocity.x,
                touch.normalizedVector.velocity.y
            )
        )

        return Ellipse()
            .rotation(.radians(CGFloat(-touch.angle)))
            .frame(
                width: size.width,
                height: size.height
            )
            .foregroundStyle(.cyan.opacity(max(CGFloat(touch.pressure / 100), 0.4)))
            .overlay {
                Path { path in
                    path.move(
                        to: CGPoint(
                            x: size.width / 2,
                            y: size.height / 2
                        )
                    )
                    path.addLine(
                        to: CGPoint(
                            x: (size.width / 2) + velocity.width,
                            y: (size.height / 2) - velocity.height
                        )
                    )
                }
                .stroke(style: .init(lineWidth: 4, lineCap: .round))
                .foregroundStyle(.yellow.opacity(max(velocityMag, 0.5)))
            }
            .offset(
                x: origin.x,
                y: origin.y
            )
            .fixedSize()
            .frame(width: 0, height: 0, alignment: .center)
    }
}

