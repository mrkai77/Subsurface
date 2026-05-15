//
//  SubsurfaceMonitor.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-02-07.
//

import Foundation
import IOKit
import Scribe

/// Monitors all multitouch devices and provides a unified stream of contacts
@Loggable
public final class SubsurfaceMonitor: @unchecked Sendable {
    /// Locks ever mutable property below
    private let stateLock = NSLock()

    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var devices: [UInt64: SubsurfaceDevice] = [:]
    private var deviceTasks: [UInt64: Task<(), Never>] = [:]

    /// Iterator `io_service_t` to device ID. Keys are retained via `IOObjectRetain` while the device is tracked
    private var deviceServices: [io_service_t: UInt64] = [:]

    private let contactSubscribers = AsyncBroadcastHub<(SubsurfaceDevice, [MTContact])>()
    private var isRunning = false

    private let notificationQueue = DispatchQueue(label: "com.MrKai77.subsurface.monitor", qos: .userInteractive)

    public init() {}

    deinit {
        stop()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    /// Start monitoring for device connections and disconnections
    public func start() {
        let alreadyRunning = withLock { isRunning }
        guard !alreadyRunning else {
            log.debug("Monitor start requested while already running")
            return
        }

        log.info("Starting device monitor")

        let port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else {
            log.error("Failed to create IONotificationPort")
            return
        }

        IONotificationPortSetDispatchQueue(port, notificationQueue)

        let addedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let monitor = Unmanaged<SubsurfaceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDevicesAdded(iterator: iterator)
        }
        let removedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let monitor = Unmanaged<SubsurfaceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDevicesRemoved(iterator: iterator)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var addedIter: io_iterator_t = 0
        let addResult = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            IOServiceMatching("AppleMultitouchDevice"),
            addedCallback,
            selfPtr,
            &addedIter
        )
        guard addResult == KERN_SUCCESS else {
            log.error("Failed to register for device added notifications: \(addResult)")
            IONotificationPortDestroy(port)
            return
        }

        var removedIter: io_iterator_t = 0
        let removeResult = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            IOServiceMatching("AppleMultitouchDevice"),
            removedCallback,
            selfPtr,
            &removedIter
        )
        guard removeResult == KERN_SUCCESS else {
            log.error("Failed to register for device removed notifications: \(removeResult)")
            IOObjectRelease(addedIter)
            IONotificationPortDestroy(port)
            return
        }

        withLock {
            notifyPort = port
            addedIterator = addedIter
            removedIterator = removedIter
            isRunning = true
        }

        // Drain both iterators once. The first pass picks up already-connected
        // devices, and is also what arms `kIOTerminatedNotification` on the
        // removed-iterator side; without it the removal callback never fires.
        handleDevicesAdded(iterator: addedIter)
        handleDevicesRemoved(iterator: removedIter)

        log.info("Device monitor started")
    }

    /// Stop monitoring and clean up all devices
    public func stop() {
        stateLock.lock()
        let wasRunning = isRunning
        let port = notifyPort
        let addedIter = addedIterator
        let removedIter = removedIterator
        let tasks = deviceTasks
        let trackedDevices = devices
        let services = Array(deviceServices.keys)
        notifyPort = nil
        addedIterator = 0
        removedIterator = 0
        deviceTasks.removeAll()
        devices.removeAll()
        deviceServices.removeAll()
        isRunning = false
        stateLock.unlock()

        let finishedSubscriberCount = contactSubscribers.finishAll()

        guard wasRunning || finishedSubscriberCount > 0 else { return }

        log.info("Stopping device monitor")

        if wasRunning {
            for task in tasks.values { task.cancel() }
            for device in trackedDevices.values { device.stop() }
            for service in services { IOObjectRelease(service) }

            if addedIter != 0 { IOObjectRelease(addedIter) }
            if removedIter != 0 { IOObjectRelease(removedIter) }
            if let port { IONotificationPortDestroy(port) }
        }

        log.info("Device monitor stopped")
    }

    /// Create an async stream of contacts from all devices.
    ///
    /// Each caller receives an independent stream, and every active subscriber
    /// receives the same contact frames broadcast by the monitor.
    public func contacts() -> AsyncStream<(SubsurfaceDevice, [MTContact])> {
        contactSubscribers.stream()
    }

    private func handleDevicesAdded(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            var consumedService = false
            defer { if !consumedService { IOObjectRelease(service) } }

            guard let device = SubsurfaceDevice(service: service) else {
                log.warn("Failed to create device from service")
                continue
            }

            guard let deviceID = device.deviceID else {
                log.warn("Device has no ID, skipping")
                continue
            }

            let alreadyTracked = withLock { devices[deviceID] != nil }
            if alreadyTracked {
                log.debug("Device \(deviceID) already tracked")
                continue
            }

            guard isLikelyTrackpad(device) else { continue }

            log.info("Device connected: \(device.name) (ID: \(deviceID))")

            guard device.start() else {
                log.error("Failed to start device \(deviceID)")
                continue
            }

            // Retain the service handle for the device's lifetime, as mach port values
            // are only stable while someone holds a reference, and this same
            // port is looked back up when `kIOTerminatedNotification` fires.
            IOObjectRetain(service)
            consumedService = true

            let task = Task { [weak self] in
                for await contacts in device.contactFrames() {
                    guard let self else { break }
                    contactSubscribers.yield((device, contacts))
                }
            }

            withLock {
                devices[deviceID] = device
                deviceServices[service] = deviceID
                deviceTasks[deviceID] = task
            }
        }
    }

    private func handleDevicesRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let removed: (device: SubsurfaceDevice, task: Task<(), Never>?)? = withLock {
                guard let deviceID = deviceServices.removeValue(forKey: service),
                      let device = devices.removeValue(forKey: deviceID) else {
                    return nil
                }
                let task = deviceTasks.removeValue(forKey: deviceID)
                return (device, task)
            }

            guard let removed else { continue }

            IOObjectRelease(service)

            log.info("Device disconnected: \(removed.device.name)")
            removed.task?.cancel()
            removed.device.stop()
        }
    }
    
    /// Heuristic check for determining if this device is a likely trackpad.
    /// Touch bars are excluded, while trackpad/magic mice are included.
    private func isLikelyTrackpad(_ device: SubsurfaceDevice) -> Bool {
        if device.familyID == 105 {
            log.debug("Skipping Touch Bar: \(device.name)")
            return false
        }
        if let dimensions = device.sensorSurfaceDimensions,
           dimensions.width > 1000, dimensions.height < 100 {
            log.debug("Skipping Touch Bar-like device: \(device.name) - \(Double(dimensions.width) / 1000)x\(Double(dimensions.height) / 1000)cm")
            return false
        }
        return true
    }

    /// Get all currently connected devices
    public var activeDevices: [SubsurfaceDevice] {
        withLock { Array(devices.values) }
    }
}
