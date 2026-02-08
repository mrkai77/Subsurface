//
//  TrackpadVisualizerLayer.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import AppKit
import Subtrack

/// CALayer-based trackpad visualizer for high-performance rendering
final class TrackpadVisualizerLayer: CALayer {
    private var touchLayers: [Int32: TouchLayer] = [:]
    private var velocityLayers: [Int32: VelocityLayer] = [:]

    var showVelocity: Bool = false
    var showContactInfo: Bool = false
    var enablePalmRejection: Bool = true

    override init() {
        super.init()
        backgroundColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        cornerRadius = 12
        borderWidth = 2
        borderColor = NSColor.tertiaryLabelColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with contacts: [MTContact]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var activeIDs = Set<Int32>()

        for contact in contacts {
            // Palm rejection
            if enablePalmRejection, contact.finger == nil {
                continue
            }

            activeIDs.insert(contact.id)

            // Get or create touch layer
            let touchLayer: TouchLayer
            if let existing = touchLayers[contact.id] {
                touchLayer = existing
            } else {
                touchLayer = TouchLayer()
                touchLayers[contact.id] = touchLayer
                addSublayer(touchLayer)
            }

            // Update touch layer
            touchLayer.update(
                contact: contact,
                canvasSize: bounds.size,
                showContactInfo: showContactInfo
            )

            // Handle velocity
            if showVelocity {
                let velocityLayer: VelocityLayer
                if let existing = velocityLayers[contact.id] {
                    velocityLayer = existing
                } else {
                    velocityLayer = VelocityLayer()
                    velocityLayers[contact.id] = velocityLayer
                    addSublayer(velocityLayer)
                }

                velocityLayer.update(contact: contact, canvasSize: bounds.size)
            } else {
                // Remove velocity layer if disabled
                if let layer = velocityLayers[contact.id] {
                    layer.removeFromSuperlayer()
                    velocityLayers.removeValue(forKey: contact.id)
                }
            }
        }

        // Remove layers for contacts that are no longer active
        let inactiveIDs = Set(touchLayers.keys).subtracting(activeIDs)
        for id in inactiveIDs {
            touchLayers[id]?.removeFromSuperlayer()
            touchLayers.removeValue(forKey: id)

            velocityLayers[id]?.removeFromSuperlayer()
            velocityLayers.removeValue(forKey: id)
        }

        CATransaction.commit()
    }
}
