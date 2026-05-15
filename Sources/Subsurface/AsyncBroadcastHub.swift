//
//  AsyncBroadcastHub.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-05-15.
//

import Foundation

/// Lightweight multicast hub for broadcasting values into independent `AsyncStream`s.
final class AsyncBroadcastHub<Value: Sendable>: @unchecked Sendable {
    private struct Subscriber {
        let yield: @Sendable (Value) -> Void
        let finish: () -> Void
    }

    private let lock = NSLock()
    private var subscribers: [UUID: Subscriber] = [:]

    var subscriberCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return subscribers.count
    }

    func stream(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Value> {
        let subscriberID = UUID()

        return AsyncStream<Value>(bufferingPolicy: bufferingPolicy) { [weak self] continuation in
            let subscriber = Subscriber(
                yield: { value in
                    continuation.yield(value)
                },
                finish: {
                    continuation.finish()
                }
            )

            self?.lock.lock()
            self?.subscribers[subscriberID] = subscriber
            self?.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.removeSubscriber(id: subscriberID)
            }
        }
    }

    func yield(_ value: Value) {
        let subscribers = snapshotSubscribers()
        for subscriber in subscribers {
            subscriber.yield(value)
        }
    }

    @discardableResult
    func finishAll() -> Int {
        let subscribers = snapshotAndRemoveAllSubscribers()
        for subscriber in subscribers {
            subscriber.finish()
        }
        return subscribers.count
    }

    private func removeSubscriber(id: UUID) {
        lock.lock()
        subscribers.removeValue(forKey: id)
        lock.unlock()
    }

    private func snapshotSubscribers() -> [Subscriber] {
        lock.lock()
        defer { lock.unlock() }
        return Array(subscribers.values)
    }

    private func snapshotAndRemoveAllSubscribers() -> [Subscriber] {
        lock.lock()
        let subscribers = Array(self.subscribers.values)
        self.subscribers.removeAll()
        lock.unlock()
        return subscribers
    }
}
