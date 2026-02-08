//
//  TrackpadVisualizerLayerView.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subtrack
import SwiftUI

/// SwiftUI wrapper
struct TrackpadVisualizerLayerView: NSViewRepresentable {
    let touchData: [MTContact]
    let showVelocity: Bool
    let showContactInfo: Bool
    let enablePalmRejection: Bool

    func makeNSView(context _: Context) -> TrackpadVisualizerNSView {
        let view = TrackpadVisualizerNSView()
        view.showVelocity = showVelocity
        view.showContactInfo = showContactInfo
        view.enablePalmRejection = enablePalmRejection
        return view
    }

    func updateNSView(_ nsView: TrackpadVisualizerNSView, context _: Context) {
        nsView.showVelocity = showVelocity
        nsView.showContactInfo = showContactInfo
        nsView.enablePalmRejection = enablePalmRejection
        nsView.update(with: touchData)
    }
}
