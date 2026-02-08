//
//  ContentView.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subtrack
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @State private var showVelocity: Bool = false
    @State private var showContactInfo: Bool = false
    @State private var enablePalmRejection: Bool = true

    var body: some View {
        HStack {
            TrackpadVisualizerLayerView(
                touchData: viewModel.touchData,
                showVelocity: showVelocity,
                showContactInfo: showContactInfo,
                enablePalmRejection: enablePalmRejection
            )
            .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
            .animation(.smooth(duration: 0.25), value: viewModel.aspectRatio)
            .frame(maxWidth: .infinity)

            Form {
                Section("Subtrack Visualizer") {
                    HStack {
                        Text("Visualization")

                        Spacer()

                        if viewModel.isListening {
                            Button("Stop", action: viewModel.stop)
                        } else {
                            Button("Start", action: viewModel.start)
                        }
                    }
                    .disabled(viewModel.trackingMode == .individual && viewModel.selectedDevice == nil)

                    Picker("Tracking Mode", selection: $viewModel.trackingMode) {
                        Text("Individual").tag(TrackingMode.individual)
                        Text("Global").tag(TrackingMode.global)
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isListening)

                    if viewModel.trackingMode == .global, let currentDevice = viewModel.currentDevice {
                        HStack {
                            Text("Last device")
                            Spacer()
                            Text(currentDevice.name)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Show velocity vector", isOn: $showVelocity)

                    Toggle("Show contact info", isOn: $showContactInfo)

                    Toggle("Palm rejection", isOn: $enablePalmRejection)
                }

                if viewModel.trackingMode == .individual {
                    Section {
                        ForEach(Array(viewModel.availableDevicesByID.keys), id: \.self) { deviceKey in
                            if let device = viewModel.availableDevicesByID[deviceKey] {
                                HStack {
                                    let isSelected = viewModel.selectedDevice?.deviceID == deviceKey
                                    if isSelected {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundStyle(.green)
                                    }

                                    Text("\(device.name)")
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button("Select") {
                                        viewModel.selectDevice(device)
                                    }
                                    .disabled(isSelected)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Device")

                            Spacer()

                            Button("Reload", action: viewModel.reloadDevices)
                                .buttonStyle(.accessoryBar)
                        }
                        .onAppear(perform: viewModel.reloadDevices)
                    }
                    .disabled(viewModel.isListening)
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

struct TrackpadVisualizer: View {
    let touchData: [MTContact]
    let aspectRatio: CGFloat
    let showVelocity: Bool
    let showContactInfo: Bool
    let enablePalmRejection: Bool

    var body: some View {
        Canvas { context, canvasSize in
            for touch in touchData {
                if enablePalmRejection {
                    guard touch.finger != nil else {
                        continue
                    }
                }

                let u = canvasSize.width / 100.0

                let x = CGFloat(touch.normalizedVector.position.x) * canvasSize.width
                let y = (1 - CGFloat(touch.normalizedVector.position.y)) * canvasSize.height

                let w = CGFloat(touch.majorAxis) * u
                let h = CGFloat(touch.minorAxis) * u

                let velocity = CGSize(
                    width: CGFloat(touch.normalizedVector.velocity.x / 5) * canvasSize.width,
                    height: CGFloat(touch.normalizedVector.velocity.y / 5) * canvasSize.height
                )
                let velocityMag = CGFloat(
                    hypot(touch.normalizedVector.velocity.x, touch.normalizedVector.velocity.y)
                )

                // Touch ellipse (transplanted transform order)
                let ellipse = Path(ellipseIn: CGRect(x: -0.5 * w, y: -0.5 * h, width: w, height: h))
                    .rotation(.radians(Double(-touch.angle)), anchor: .topLeading)
                    .offset(x: x, y: y)
                    .path(in: CGRect(origin: .zero, size: canvasSize))

                context.fill(
                    ellipse,
                    with: .color(.cyan.opacity(max(CGFloat(touch.pressure / 100), 0.4)))
                )

                if showContactInfo {
                    let text = Text("""
                    \(Text(touch.contactState.description).bold())
                    \(touch.hand?.description ?? "Unknwon") \(touch.finger?.description ?? "Unknown")
                    ID \(touch.id)
                    """)

                    context.draw(
                        text,
                        at: CGPoint(x: x, y: y - h),
                        anchor: .bottom
                    )
                }

                if showVelocity {
                    // Velocity arrow
                    let start = CGPoint(x: x, y: y)
                    let end = CGPoint(x: x + velocity.width, y: y - velocity.height)

                    var arrow = Path()
                    arrow.move(to: start)
                    arrow.addLine(to: end)

                    // Arrow head scales with velocity magnitude (clamped)
                    let headLength = CGFloat(4 + 16 * velocityMag) // 6...28
                    let headAngle = CGFloat((.pi / 10) + (.pi / 10) * velocityMag) // ~18°...36°

                    let dx = end.x - start.x
                    let dy = end.y - start.y
                    let theta = atan2(dy, dx)

                    let a1 = theta + .pi - headAngle
                    let a2 = theta + .pi + headAngle

                    let p1 = CGPoint(x: end.x + headLength * cos(a1), y: end.y + headLength * sin(a1))
                    let p2 = CGPoint(x: end.x + headLength * cos(a2), y: end.y + headLength * sin(a2))

                    arrow.move(to: end)
                    arrow.addLine(to: p1)
                    arrow.move(to: end)
                    arrow.addLine(to: p2)

                    context.stroke(
                        arrow,
                        with: .color(.yellow.opacity(max(velocityMag, 0.5))),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .overlay(.tertiary, in: .rect(cornerRadius: 12).stroke(lineWidth: 2))
        .background(.quinary, in: .rect(cornerRadius: 12))
        .aspectRatio(aspectRatio, contentMode: .fit)
        .animation(.smooth(duration: 0.25), value: aspectRatio)
    }
}
