//
//  AsyncBroadcastHubTests.swift
//  SubsurfaceTests
//
//  Created by Kai Azim on 2026-05-15.
//

@testable import Subsurface
import Testing

struct AsyncBroadcastHubTests {
    @Test("Broadcast hub sends values to all subscribers")
    func broadcastsToAllSubscribers() async {
        let hub = AsyncBroadcastHub<Int>()
        let firstStream = hub.stream()
        let secondStream = hub.stream()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()

        hub.yield(42)

        let firstReceived = await firstIterator.next()
        let secondReceived = await secondIterator.next()

        #expect(firstReceived == 42)
        #expect(secondReceived == 42)
    }

    @Test("Cancelling one subscriber leaves the others active")
    func cancellingOneSubscriberDoesNotAffectOthers() async {
        let hub = AsyncBroadcastHub<Int>()
        let firstStream = hub.stream()
        let secondStream = hub.stream()

        let firstTask = Task {
            var iterator = firstStream.makeAsyncIterator()
            while await iterator.next() != nil {}
        }
        let secondTask = Task {
            var iterator = secondStream.makeAsyncIterator()
            return await iterator.next()
        }

        firstTask.cancel()
        await firstTask.value
        await waitUntilSubscriberCount(hub, equals: 1)

        hub.yield(7)
        let secondReceived = await secondTask.value

        #expect(secondReceived == 7)
        #expect(hub.subscriberCount == 1)
    }

    @Test("Finishing the hub closes all active subscribers")
    func finishAllClosesSubscribers() async {
        let hub = AsyncBroadcastHub<Int>()
        let firstStream = hub.stream()
        let secondStream = hub.stream()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()

        let finishedCount = hub.finishAll()
        let firstReceived = await firstIterator.next()
        let secondReceived = await secondIterator.next()

        #expect(finishedCount == 2)
        #expect(firstReceived == nil)
        #expect(secondReceived == nil)
        #expect(hub.subscriberCount == 0)
    }

    private func waitUntilSubscriberCount(_ hub: AsyncBroadcastHub<Int>, equals expected: Int) async {
        for _ in 0 ..< 20 where hub.subscriberCount != expected {
            await Task.yield()
        }
    }
}
