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
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 1.0 / 60.0 // 60 FPS
    private var lastContactStates: [Int32: Int32] = [:] // Track contact states by ID

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

    private func shouldUpdate(contacts: [MTContact], now: TimeInterval) -> Bool {
        // Build current state map
        let currentStates = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0.contactState.rawValue) })

        // Always update if contact count changed
        if currentStates.count != lastContactStates.count {
            return true
        }

        // Check for state changes
        for (id, state) in currentStates {
            if lastContactStates[id] != state {
                return true
            }
        }

        // Check for removed contacts
        for id in lastContactStates.keys {
            if currentStates[id] == nil {
                return true
            }
        }

        // Otherwise, throttle based on time
        return now - lastUpdateTime >= updateInterval
    }

    private func startIndividual() {
        guard let device = selectedDevice else { return }

        task?.cancel()
        task = Task { [weak self] in
            guard let device = self?.selectedDevice else { return }
            for await touches in device.contactFrames() {
                guard !Task.isCancelled else { return }

                let now = CACurrentMediaTime()
                guard let self, shouldUpdate(contacts: touches, now: now) else {
                    continue
                }

                lastUpdateTime = now
                lastContactStates = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.contactState.rawValue) })
                touchData = touches
                currentDevice = device
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
        lastUpdateTime = 0
        lastContactStates = [:]

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
                guard !Task.isCancelled else { return }

                let now = CACurrentMediaTime()
                guard let self, shouldUpdate(contacts: touches, now: now) else {
                    continue
                }

                lastUpdateTime = now
                lastContactStates = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.contactState.rawValue) })

                // Always update touch data
                touchData = touches

                // Only update device and aspect ratio if device actually changed
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
        lastUpdateTime = 0
        lastContactStates = [:]
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
