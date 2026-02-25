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
    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private let notificationQueue = DispatchQueue(label: "com.MrKai77.subsurface.monitor", qos: .userInteractive)

    private var devices: [UInt64: SubsurfaceDevice] = [:]
    private var deviceTasks: [UInt64: Task<(), Never>] = [:]
    private var deviceServices: [io_service_t: UInt64] = [:] // Maps IOService to device ID
    private var contactContinuation: AsyncStream<(SubsurfaceDevice, [MTContact])>.Continuation?
    private var isRunning = false

    public init() {}

    deinit {
        stop()
    }

    /// Start monitoring for device connections and disconnections
    public func start() {
        guard !isRunning else {
            log.warn("Monitor is already running")
            return
        }

        log.info("Starting device monitor")

        // Create notification port
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else {
            log.error("Failed to create IONotificationPort")
            return
        }

        IONotificationPortSetDispatchQueue(notifyPort, notificationQueue)
        let matchingDict = IOServiceMatching("AppleMultitouchDevice")

        // Register for device added notifications
        let addedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let monitor = Unmanaged<SubsurfaceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDevicesAdded(iterator: iterator)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let addResult = IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingDict,
            addedCallback,
            selfPtr,
            &addedIterator
        )

        guard addResult == KERN_SUCCESS else {
            log.error("Failed to register for device added notifications: \(addResult)")
            return
        }

        // Process any devices that are already connected
        handleDevicesAdded(iterator: addedIterator)

        // Register for device removed notifications
        let removedMatchingDict = IOServiceMatching("AppleMultitouchDevice")
        let removedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let monitor = Unmanaged<SubsurfaceMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDevicesRemoved(iterator: iterator)
        }

        let removeResult = IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            removedMatchingDict,
            removedCallback,
            selfPtr,
            &removedIterator
        )

        guard removeResult == KERN_SUCCESS else {
            log.error("Failed to register for device removed notifications: \(removeResult)")
            return
        }

        // Prepare the notification
        handleDevicesRemoved(iterator: removedIterator)

        isRunning = true
        log.info("Device monitor started")
    }

    /// Stop monitoring and clean up all devices
    public func stop() {
        guard isRunning else { return }

        log.info("Stopping device monitor")

        // Cancel all device tasks
        for (_, task) in deviceTasks {
            task.cancel()
        }
        deviceTasks.removeAll()

        // Clean up all devices
        for (_, device) in devices {
            device.stop()
        }
        devices.removeAll()
        deviceServices.removeAll()

        // Release iterators
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }

        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }

        // Destroy notification port
        if let notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }

        // Finish contact stream
        contactContinuation?.finish()
        contactContinuation = nil

        isRunning = false
        log.info("Device monitor stopped")
    }

    /// Create an async stream of contacts from all devices
    public func contacts() -> AsyncStream<(SubsurfaceDevice, [MTContact])> {
        if contactContinuation != nil {
            log.warn("Contact stream already exists")
        }

        let stream = AsyncStream<(SubsurfaceDevice, [MTContact])>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.contactContinuation = continuation

            continuation.onTermination = { _ in
                self.contactContinuation = nil
            }
        }

        return stream
    }

    private func handleDevicesAdded(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let device = SubsurfaceDevice(service: service) else {
                log.warn("Failed to create device from service")
                continue
            }

            guard let deviceID = device.deviceID else {
                log.warn("Device has no ID, skipping")
                continue
            }

            // Skip if we already have this device
            guard devices[deviceID] == nil else {
                log.debug("Device \(deviceID) already tracked")
                continue
            }

            if let dimensions = device.sensorSurfaceDimensions,
               dimensions.width < 2500 || dimensions.height < 2500 {
                log.debug("Skipping potential non-trackpad device: \(device.name) - dimensions: \(Double(dimensions.width) / 1000)x\(Double(dimensions.height) / 1000)cm")
                continue
            }

            log.info("Device connected: \(device.name) (ID: \(deviceID))")

            // Store the IOService mapping for removal tracking
            if let deviceService = device.service {
                deviceServices[deviceService] = deviceID
            }

            // Start the device
            guard device.start() else {
                log.error("Failed to start device \(deviceID)")
                continue
            }

            // Store the device
            devices[deviceID] = device

            // Set up contact stream for this device
            let task = Task {
                for await contacts in device.contactFrames() {
                    self.contactContinuation?.yield((device, contacts))
                }
            }
            deviceTasks[deviceID] = task
        }
    }

    private func handleDevicesRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard let deviceID = deviceServices[service] else {
                continue
            }

            guard let device = devices[deviceID] else {
                continue
            }

            log.info("Device disconnected: \(device.name) (ID: \(deviceID))")

            // Cancel the task
            deviceTasks[deviceID]?.cancel()
            deviceTasks.removeValue(forKey: deviceID)

            // Stop and remove device
            device.stop()
            devices.removeValue(forKey: deviceID)
            deviceServices.removeValue(forKey: service)
        }
    }

    // MARK: - Device Access

    /// Get all currently connected devices
    public var activeDevices: [SubsurfaceDevice] {
        Array(devices.values)
    }
}
