//
//  ContentViewModel.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-02-01.
//

import SwiftUI

@Observable
@MainActor
final class ContentViewModel {
    private(set) var touchData = [MTContact]()
    private(set) var isListening: Bool = false

    private let manager = MultitouchManager.shared
    private var currentDevice: MultitouchDevice? = MultitouchManager.shared.defaultDevice
    private var task: Task<(), Never>?
    private var isCurrentlyHovering: Bool = false

    func onAppear() {
        task = Task { [weak self] in
            guard let device = self?.currentDevice else { return }
            print("Found device: \(device)")

            for await touches in device.contactFrames() {
                self?.touchData = touches

                print(touches.map(\.density))
            }
        }
    }

    func onDisappear() {
        task?.cancel()
        stop()
    }

    func start() {
        guard let device = currentDevice else { return }
        if device.start() {
            isListening = true
        }
    }

    func stop() {
        guard let device = currentDevice else { return }
        if device.stop() {
            isListening = false
        }
    }
}
