//
//  MultitouchCallbackManager.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

final class MultitouchCallbackManager {
    static let shared = MultitouchCallbackManager()

    private var contactHandlers: [MTDeviceRef: AsyncStream<[MTContact]>.Continuation] = [:]
    private var pathHandlers: [MTDeviceRef: AsyncStream<(MTContact, Int, Int)>.Continuation] = [:]
    private let lock = NSLock()

    private init() {}

    func registerContactFrameCallback(for device: MTDeviceRef) -> AsyncStream<[MTContact]> {
        let stream = AsyncStream<[MTContact]> { continuation in
            lock.lock()
            contactHandlers[device] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.contactHandlers.removeValue(forKey: device)
                self?.lock.unlock()
            }
        }

        let callback: MTContactCallbackFunction = { device, dataPtr, numTouches, _, _ in
            MultitouchCallbackManager.shared.lock.lock()
            defer { MultitouchCallbackManager.shared.lock.unlock() }

            guard let continuation = MultitouchCallbackManager.shared.contactHandlers[device] else {
                return 0
            }

            let touches = UnsafeBufferPointer(
                start: dataPtr.assumingMemoryBound(to: MTContact.self),
                count: Int(numTouches)
            )
            continuation.yield(touches.map(\.self))
            return 0
        }

        MTRegisterContactFrameCallback(device, callback)
        return stream
    }

    func unregisterContactFrameCallback(for device: MTDeviceRef) {
        lock.lock()
        if let continuation = contactHandlers[device] {
            continuation.finish()
            contactHandlers.removeValue(forKey: device)
        }
        lock.unlock()

        MTUnregisterContactFrameCallback(device, nil)
    }

    func registerPathCallback(for device: MTDeviceRef) -> AsyncStream<(MTContact, Int, Int)> {
        let stream = AsyncStream<(MTContact, Int, Int)> { continuation in
            lock.lock()
            pathHandlers[device] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.pathHandlers.removeValue(forKey: device)
                self?.lock.unlock()
            }
        }

        let callback: MTPathCallbackFunction = { device, pathID, state, touchPtr in
            MultitouchCallbackManager.shared.lock.lock()
            defer { MultitouchCallbackManager.shared.lock.unlock() }

            guard let continuation = MultitouchCallbackManager.shared.pathHandlers[device] else {
                return
            }

            let touch = touchPtr.assumingMemoryBound(to: MTContact.self).pointee
            continuation.yield((touch, pathID, state))
        }

        MTRegisterPathCallback(device, callback)
        return stream
    }

    func unregisterPathCallback(for device: MTDeviceRef) {
        lock.lock()
        if let continuation = pathHandlers[device] {
            continuation.finish()
            pathHandlers.removeValue(forKey: device)
        }
        lock.unlock()

        MTUnregisterPathCallback(device, nil)
    }
}
