//
//  ContentViewModel.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subtrack
import SwiftUI

enum TrackingMode {
    case individual
    case global
}

@Observable
@MainActor
final class ContentViewModel {
    private(set) var touchData = [MTContact]()
    private(set) var isListening: Bool = false
    private(set) var aspectRatio: CGFloat = 1.0
    private(set) var currentDevice: SubtrackDevice?

    private(set) var selectedDevice: SubtrackDevice?
    private(set) var availableDevicesByID: [UInt64: SubtrackDevice] = [:]

    var trackingMode: TrackingMode = .individual

    private var task: Task<(), Never>?
    private var monitor: SubtrackMonitor?

    func start() {
        switch trackingMode {
        case .individual:
            startIndividual()
        case .global:
            startGlobal()
        }
    }

    func stop() {
        switch trackingMode {
        case .individual:
            stopIndividual()
        case .global:
            stopGlobal()
        }
    }

    private func startIndividual() {
        guard let device = selectedDevice else { return }

        task?.cancel()
        task = Task { [weak self] in
            guard let device = self?.selectedDevice else { return }
            for await touches in device.contactFrames() {
                autoreleasepool {
                    guard !Task.isCancelled else { return }
                    guard let self else { return }

                    touchData = touches
                    currentDevice = device
                }
            }
        }

        if device.start() {
            isListening = true
        }
    }

    private func stopIndividual() {
        guard let device = selectedDevice else { return }

        task?.cancel()
        touchData = []
        currentDevice = nil

        if device.stop() {
            isListening = false
        }
    }

    private func startGlobal() {
        let newMonitor = SubtrackMonitor()
        monitor = newMonitor

        task?.cancel()
        task = Task { [weak self] in
            newMonitor.start()

            for await (device, touches) in newMonitor.contacts() {
                autoreleasepool {
                    guard !Task.isCancelled else { return }
                    guard let self else { return }

                    self.touchData = touches

                    if self.currentDevice?.deviceID != device.deviceID {
                        self.currentDevice = device

                        if let dimensions = device.sensorDimensions {
                            self.aspectRatio = CGFloat(dimensions.columns) / CGFloat(dimensions.rows)
                        }
                    }
                }
            }
        }

        isListening = true
    }

    private func stopGlobal() {
        task?.cancel()
        monitor?.stop()
        monitor = nil
        touchData = []
        currentDevice = nil
        isListening = false
    }

    func reloadDevices() {
        availableDevicesByID = Dictionary(
            SubtrackDevice.allDevices.map { ($0.deviceID ?? 0, $0) },
            uniquingKeysWith: { _, new in new }
        )
    }

    func selectDevice(_ device: SubtrackDevice) {
        selectedDevice = device

        if let dimensions = device.sensorDimensions {
            aspectRatio = CGFloat(dimensions.columns) / CGFloat(dimensions.rows)
        }
    }
}
