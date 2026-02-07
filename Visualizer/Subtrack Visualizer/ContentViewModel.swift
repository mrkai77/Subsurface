//
//  ContentViewModel.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import SwiftUI
import Subtrack

@Observable
@MainActor
final class ContentViewModel {
    private(set) var touchData = [MTContact]()
    private(set) var isListening: Bool = false
    private(set) var aspectRatio: CGFloat = 1.0

    private(set) var selectedDevice: SubtrackDevice?
    private(set) var availableDevicesByID: [UInt64: SubtrackDevice] = [:]

    private var task: Task<(), Never>?

    func start() {
        guard let device = selectedDevice else { return }
        
        task?.cancel()
        task = Task { [weak self] in
            guard let device = self?.selectedDevice else { return }
            for await touches in device.contactFrames() {
                guard !Task.isCancelled else { return }
                self?.touchData = touches
            }
        }

        if let dimensions = device.sensorDimensions {
            aspectRatio = CGFloat(dimensions.columns) / CGFloat(dimensions.rows)
        }

        if device.start() {
            isListening = true
        }
    }

    func stop() {
        guard let device = selectedDevice else { return }

        task?.cancel()
        touchData = []
        aspectRatio = 1.0

        if device.stop() {
            isListening = false
        }
    }
    
    func reloadDevices() {
        availableDevicesByID = Dictionary(
            Subtrack.allDevices.map { ($0.deviceID ?? 0, $0) },
            uniquingKeysWith: { old, new in new }
        )
    }
    
    func selectDevice(_ device: SubtrackDevice) {
        selectedDevice = device
    }
}
