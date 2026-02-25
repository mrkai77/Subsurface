//
//  ContentViewModel.swift
//  Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subsurface
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
    private(set) var aspectRatio: CGFloat = 24.0 / 18.0
    private(set) var currentDevice: SubsurfaceDevice?

    private(set) var selectedDevice: SubsurfaceDevice?
    private(set) var availableDevicesByID: [UInt64: SubsurfaceDevice] = [:]

    var trackingMode: TrackingMode = .global
    var showVelocity: Bool = false
    var showContactInfo: Bool = false
    var enablePalmRejection: Bool = true

    private var task: Task<(), Never>?
    private var monitor: SubsurfaceMonitor?

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
                guard !Task.isCancelled else { return }
                guard let self else { return }

                touchData = touches
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
        let newMonitor = SubsurfaceMonitor()
        monitor = newMonitor

        task?.cancel()
        task = Task { [weak self] in
            newMonitor.start()

            for await (device, touches) in newMonitor.contacts() {
                guard !Task.isCancelled else { return }
                guard let self else { return }

                touchData = touches

                if currentDevice?.deviceID != device.deviceID {
                    currentDevice = device

                    if let dimensions = device.sensorDimensions {
                        aspectRatio = CGFloat(dimensions.columns) / CGFloat(dimensions.rows)
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
            SubsurfaceDevice.allDevices.map { ($0.deviceID ?? 0, $0) },
            uniquingKeysWith: { _, new in new }
        )
    }

    func selectDevice(_ device: SubsurfaceDevice) {
        selectedDevice = device

        if let dimensions = device.sensorDimensions {
            aspectRatio = CGFloat(dimensions.columns) / CGFloat(dimensions.rows)
        }
    }
    
    func runActuation(pattern: MTFeedbackPattern) {
        for device in SubsurfaceDevice.allDevices {
            if let actuator = device.actuator {
                actuator.open()
                actuator.actuate(pattern: pattern)
                actuator.close()
            }
        }
    }
}
