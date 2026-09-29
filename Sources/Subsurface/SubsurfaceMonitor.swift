//
//  SubsurfaceMonitor.swift
//  Subsurface
//
//  Created by Kai Azim on 2026-02-07.
//

import AppKit
import IOKit
import Scribe

/// Monitors all multitouch devices and provides a unified stream of contacts.
///
/// Devices are tracked by IORegistry entry ID. A device that fails to be created or
/// started is retried with backoff, and all devices are fully rebuilt after the system
/// wakes or the user session becomes active again. Subscriber streams stay open across
/// these rebuilds and only finish when ``stop()`` is called.
@Loggable
public final class SubsurfaceMonitor: @unchecked Sendable {
    /// A tracked `AppleMultitouchDevice` service. Only accessed on `notificationQueue`.
    private final class TrackedService {
        let registryID: UInt64

        /// Retained via `IOObjectRetain` while tracked
        let service: io_service_t

        var device: SubsurfaceDevice?
        var deviceID: UInt64?
        var failedAttempts = 0
        var retryWorkItem: DispatchWorkItem?

        init(registryID: UInt64, service: io_service_t) {
            self.registryID = registryID
            self.service = service
        }
    }

    /// Delays between start attempts for a device that failed to be created or started.
    /// Once exhausted, the device is left idle until the next device-added, wake or session event.
    private static let retryDelays: [TimeInterval] = [0.5, 1, 2, 4, 8]

    /// How long to wait after wake before rebuilding, letting drivers settle
    private static let wakeRebuildDelay: TimeInterval = 2

    private let notificationQueue = DispatchQueue(label: "com.MrKai77.subsurface.monitor", qos: .userInteractive)
    private let queueKey = DispatchSpecificKey<Void>()

    // State below is only accessed on `notificationQueue`
    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var trackedServices: [UInt64: TrackedService] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var wakeRebuildWorkItem: DispatchWorkItem?
    private var isSessionActive = true
    private var isRunning = false

    /// Snapshot of running devices by registry ID, readable from any thread
    private let stateLock = NSLock()
    private var runningDevices: [UInt64: SubsurfaceDevice] = [:]

    /// Unbounded, since a newest-only buffer would let one device's frame overwrite
    /// another device's zero-contact frame, leaving consumers with stuck finger counts.
    private let contactSubscribers = AsyncBroadcastHub<(SubsurfaceDevice, [MTContact])>()

    public init() {
        notificationQueue.setSpecific(key: queueKey, value: ())
    }

    deinit {
        stop()
    }

    /// Runs `body` on `notificationQueue`, directly if already on it
    private func onQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return body()
        }
        return notificationQueue.sync(execute: body)
    }

    /// Start monitoring for device connections and disconnections
    public func start() {
        onQueue { startOnQueue() }
    }

    private func startOnQueue() {
        guard !isRunning else {
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

        notifyPort = port
        addedIterator = addedIter
        removedIterator = removedIter
        isSessionActive = true
        isRunning = true

        addWorkspaceObservers()

        // Drain both iterators once. The first pass picks up already-connected
        // devices, and is also what arms `kIOTerminatedNotification` on the
        // removed-iterator side; without it the removal callback never fires.
        handleDevicesAdded(iterator: addedIter)
        handleDevicesRemoved(iterator: removedIter)

        log.info("Device monitor started")
    }

    /// Stop monitoring, clean up all devices and finish all contact streams
    public func stop() {
        let wasRunning = onQueue { stopOnQueue() }

        // Devices were torn down first, so subscribers already received their zero-contact frames
        let finishedSubscriberCount = contactSubscribers.finishAll()

        if wasRunning || finishedSubscriberCount > 0 {
            log.info("Device monitor stopped")
        }
    }

    private func stopOnQueue() -> Bool {
        guard isRunning else { return false }

        log.info("Stopping device monitor")

        removeWorkspaceObservers()
        wakeRebuildWorkItem?.cancel()
        wakeRebuildWorkItem = nil

        for tracked in trackedServices.values {
            untrack(tracked)
        }
        trackedServices.removeAll()

        if addedIterator != 0 { IOObjectRelease(addedIterator) }
        if removedIterator != 0 { IOObjectRelease(removedIterator) }
        if let notifyPort { IONotificationPortDestroy(notifyPort) }
        notifyPort = nil
        addedIterator = 0
        removedIterator = 0
        isRunning = false

        return true
    }

    /// Create an async stream of contacts from all devices.
    ///
    /// Each caller receives an independent stream, and every active subscriber
    /// receives the same contact frames broadcast by the monitor. Frames are not
    /// coalesced, and a device always delivers a zero-contact frame when it is
    /// removed, stopped or rebuilt. The stream stays open across internal rebuilds
    /// (wake, session changes, device retries) and only finishes on ``stop()``.
    public func contacts() -> AsyncStream<(SubsurfaceDevice, [MTContact])> {
        contactSubscribers.stream(bufferingPolicy: .unbounded)
    }

    /// Get all currently running devices
    public var activeDevices: [SubsurfaceDevice] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return Array(runningDevices.values)
    }

    // MARK: - Service Tracking

    private func handleDevicesAdded(iterator: io_iterator_t) {
        var addedAny = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            track(service: service)
            IOObjectRelease(service)
            addedAny = true
        }

        // A new device appearing is also a good moment to retry devices whose backoff ran out
        if addedAny {
            retryExhaustedDevices()
        }
    }

    private func handleDevicesRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let registryID = registryEntryID(of: service)
            let tracked = registryID.flatMap { trackedServices[$0] }
                ?? trackedServices.values.first { $0.service == service }
            guard let tracked else { continue }

            log.info("Device removed: \(describe(tracked))")
            trackedServices.removeValue(forKey: tracked.registryID)
            untrack(tracked)
        }
    }

    /// Starts tracking `service`. The caller keeps its own reference.
    private func track(service: io_service_t) {
        guard isRunning else { return }

        guard let registryID = registryEntryID(of: service) else {
            log.warn("Skipping multitouch service without a registry entry ID")
            return
        }

        if let existing = trackedServices[registryID] {
            if existing.device != nil {
                log.debug("Service \(registryID) already tracked and running")
                return
            }

            // Tracked but not running (waiting on a retry, or retries ran out): start over
            existing.retryWorkItem?.cancel()
            existing.retryWorkItem = nil
            existing.failedAttempts = 0
            attemptStart(existing)
            return
        }

        IOObjectRetain(service)
        let tracked = TrackedService(registryID: registryID, service: service)
        trackedServices[registryID] = tracked
        log.debug("Tracking multitouch service \(registryID)")

        attemptStart(tracked)
    }

    /// Stops the device (emitting its zero-contact frame), cancels retries and releases the service.
    /// The caller is responsible for removing `tracked` from `trackedServices`.
    private func untrack(_ tracked: TrackedService) {
        tracked.retryWorkItem?.cancel()
        tracked.retryWorkItem = nil
        stopDevice(of: tracked)
        IOObjectRelease(tracked.service)
    }

    // MARK: - Device Lifecycle

    private func attemptStart(_ tracked: TrackedService) {
        guard isRunning, isSessionActive, tracked.device == nil else { return }

        let attempt = tracked.failedAttempts + 1
        log.info("Starting device for service \(tracked.registryID) (attempt \(attempt))")

        guard let device = SubsurfaceDevice(service: tracked.service) else {
            log.warn("Failed to create device from service \(tracked.registryID)")
            scheduleRetry(tracked)
            return
        }

        guard isLikelyTrackpad(device) else {
            trackedServices.removeValue(forKey: tracked.registryID)
            untrack(tracked)
            return
        }

        let deviceID = device.deviceID
        tracked.deviceID = deviceID

        // A re-enumerated service for a device that is still tracked under its old
        // service replaces it, since the old device ref will not deliver frames anymore
        if let deviceID {
            let stale = trackedServices.values.filter {
                $0.registryID != tracked.registryID && $0.deviceID == deviceID
            }
            for old in stale {
                log.info("Replacing \(describe(old)) with re-enumerated service \(tracked.registryID)")
                trackedServices.removeValue(forKey: old.registryID)
                untrack(old)
            }
        }

        // Register before starting so the first frames aren't missed
        let hub = contactSubscribers
        let callbackRegistered = device.setContactHandler { [unowned device] contacts in
            hub.yield((device, contacts))
        }

        guard callbackRegistered, device.start() else {
            log.error("Failed to start \(device.name) (service \(tracked.registryID), callback registered: \(callbackRegistered))")
            device.stop()
            scheduleRetry(tracked)
            return
        }

        tracked.device = device
        tracked.failedAttempts = 0
        stateLock.withLock { runningDevices[tracked.registryID] = device }

        if device.kind == .magicMouse {
            log.info("Device started: \(describe(tracked)); excluded from gesture recognition")
        } else {
            log.info("Device started: \(describe(tracked))")
        }
    }

    private func stopDevice(of tracked: TrackedService) {
        guard let device = tracked.device else { return }
        tracked.device = nil
        stateLock.withLock { _ = runningDevices.removeValue(forKey: tracked.registryID) }
        device.stop()
    }

    private func scheduleRetry(_ tracked: TrackedService) {
        tracked.retryWorkItem?.cancel()
        tracked.retryWorkItem = nil

        guard tracked.failedAttempts < Self.retryDelays.count else {
            log.error("Giving up on service \(tracked.registryID) after \(tracked.failedAttempts + 1) attempts; waiting for the next device, wake or session event")
            return
        }

        let delay = Self.retryDelays[tracked.failedAttempts]
        tracked.failedAttempts += 1

        log.info("Retrying service \(tracked.registryID) in \(delay)s")

        let workItem = DispatchWorkItem { [weak self, weak tracked] in
            guard let self, let tracked, trackedServices[tracked.registryID] === tracked else { return }
            tracked.retryWorkItem = nil
            attemptStart(tracked)
        }
        tracked.retryWorkItem = workItem
        notificationQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Restarts the retry schedule for tracked services that have no running device and no pending retry
    private func retryExhaustedDevices() {
        for tracked in trackedServices.values where tracked.device == nil && tracked.retryWorkItem == nil {
            // An earlier start in this loop may have replaced this entry and released its service
            guard trackedServices[tracked.registryID] === tracked else { continue }
            log.info("Retrying idle service \(tracked.registryID)")
            tracked.failedAttempts = 0
            attemptStart(tracked)
        }
    }

    /// Fully rebuilds every device: unregisters callbacks, stops and releases all devices
    /// and services, then re-enumerates. Subscriber streams are left open.
    private func rebuild(reason: String) {
        guard isRunning else { return }

        log.info("Rebuilding devices (\(reason))")

        for tracked in trackedServices.values {
            untrack(tracked)
        }
        trackedServices.removeAll()

        guard isSessionActive else { return }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleMultitouchDevice"),
            &iterator
        )
        guard result == KERN_SUCCESS else {
            log.error("Failed to enumerate multitouch services during rebuild: \(result)")
            return
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            track(service: service)
            IOObjectRelease(service)
        }

        log.info("Rebuild finished with \(runningDeviceCount) running device(s)")
    }

    /// Stops all devices while the session is inactive, keeping services tracked
    private func stopDevicesForInactiveSession() {
        for tracked in trackedServices.values {
            tracked.retryWorkItem?.cancel()
            tracked.retryWorkItem = nil
            stopDevice(of: tracked)
        }
    }

    // MARK: - Workspace Events

    private func addWorkspaceObservers() {
        workspaceObservers = [
            observeWorkspace(NSWorkspace.didWakeNotification) { monitor in
                monitor.scheduleWakeRebuild()
            },
            observeWorkspace(NSWorkspace.sessionDidBecomeActiveNotification) { monitor in
                monitor.isSessionActive = true
                monitor.wakeRebuildWorkItem?.cancel()
                monitor.wakeRebuildWorkItem = nil
                monitor.rebuild(reason: "session became active")
            },
            observeWorkspace(NSWorkspace.sessionDidResignActiveNotification) { monitor in
                monitor.log.info("Session resigned active; stopping devices")
                monitor.isSessionActive = false
                monitor.wakeRebuildWorkItem?.cancel()
                monitor.wakeRebuildWorkItem = nil
                monitor.stopDevicesForInactiveSession()
            }
        ]
    }

    /// Observes a workspace notification, running `handler` on `notificationQueue` while the monitor is running
    private func observeWorkspace(
        _ name: Notification.Name,
        handler: @escaping @Sendable (SubsurfaceMonitor) -> ()
    ) -> NSObjectProtocol {
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
            self?.notificationQueue.async { [weak self] in
                guard let self, isRunning else { return }
                handler(self)
            }
        }
    }

    private func removeWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            center.removeObserver(observer)
        }
        workspaceObservers.removeAll()
    }

    private func scheduleWakeRebuild() {
        log.info("System woke; rebuilding devices in \(Self.wakeRebuildDelay)s")

        wakeRebuildWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            wakeRebuildWorkItem = nil
            rebuild(reason: "wake")
        }
        wakeRebuildWorkItem = workItem
        notificationQueue.asyncAfter(deadline: .now() + Self.wakeRebuildDelay, execute: workItem)
    }

    // MARK: - Helpers

    private var runningDeviceCount: Int {
        stateLock.withLock { runningDevices.count }
    }

    private func registryEntryID(of service: io_service_t) -> UInt64? {
        var entryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &entryID) == KERN_SUCCESS else { return nil }
        return entryID
    }

    private func describe(_ tracked: TrackedService) -> String {
        guard let device = tracked.device else {
            return "service \(tracked.registryID)"
        }
        let deviceID = tracked.deviceID.map(String.init) ?? "nil"
        return "\(device.name) (kind: \(device.kind), ID: \(deviceID), service: \(tracked.registryID))"
    }

    /// Heuristic check for determining if this device is a likely trackpad.
    /// Touch bars are excluded, while trackpads and Magic Mice are included
    /// (Magic Mice are reported with ``SubsurfaceDevice/Kind/magicMouse``).
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
}
