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
                    let path = makeEllipse(touch: touch, size: size)
                    context.fill(path, with: .color(.primary.opacity(Double(touch.totalCapacitance))))
                }
            }
            .frame(width: 600, height: 400)
            .border(Color.primary)
        }
        .fixedSize()
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private func makeEllipse(touch: MTContact, size: CGSize) -> Path {
        let x = Double(touch.normalizedVector.position.x) * size.width
        let y = Double(1.0 - touch.normalizedVector.position.y) * size.height
        let u = size.width / 100.0
        let w = Double(touch.majorAxis) * u
        let h = Double(touch.minorAxis) * u
        return Path(ellipseIn: CGRect(x: -0.5 * w, y: -0.5 * h, width: w, height: h))
            .rotation(.radians(Double(-touch.angle)), anchor: .topLeading)
            .offset(x: x, y: y)
            .path(in: CGRect(origin: .zero, size: size))
    }
}
