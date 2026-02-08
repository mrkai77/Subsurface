//
//  TrackpadVisualizerNSView.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import AppKit
import Subtrack

/// NSView wrapper for the CALayer visualizer
final class TrackpadVisualizerNSView: NSView {
    private let visualizerLayer = TrackpadVisualizerLayer()

    var showVelocity: Bool = false {
        didSet { visualizerLayer.showVelocity = showVelocity }
    }

    var showContactInfo: Bool = false {
        didSet { visualizerLayer.showContactInfo = showContactInfo }
    }

    var enablePalmRejection: Bool = true {
        didSet { visualizerLayer.enablePalmRejection = enablePalmRejection }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = visualizerLayer
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with contacts: [MTContact]) {
        visualizerLayer.update(with: contacts)
    }

    override func layout() {
        super.layout()
        visualizerLayer.frame = bounds
    }
}
