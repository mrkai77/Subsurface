<div align="center">
  <h1><b>Subsurface</b></h1>
  <p>Raw multitouch, gestures, and haptics for macOS.<br>
</div>

Subsurface gives Swift apps direct access to the Mac's multitouch devices. It wraps Apple's private `MultitouchSupport.framework` in a friendlier API for reading raw contact frames, tracking connected trackpads, recognizing pan/pinch/rotation gestures, and triggering Force Touch haptics.

## Installation

To add Subsurface to your Xcode project, you can use Swift Package Manager (SPM). Follow these steps:

1. Open your project in Xcode.
2. Go to `File` > `Add Package Dependencies...`.
3. Enter this URL: `https://github.com/mrkai77/Subsurface`
4. Add the `Subsurface` library to your target.

Subsurface currently targets macOS 13 and later.

## Usage

The examples below show the main layers of the package. You can work with a single device directly, listen globally through a monitor, feed contact frames into a gesture recognizer, or use the trackpad actuator for haptic feedback.

### Reading Contacts From One Device

```swift
import Subsurface

guard let device = SubsurfaceDevice.defaultDevice else {
    return
}

device.start()

for await contacts in device.contactFrames() {
    for contact in contacts {
        let position = contact.normalizedVector.position
        print("finger \(contact.id): \(position.x), \(position.y)")
    }
}
```

`MTContact` exposes the contact state, finger and hand classification, normalized position, velocity, pressure, angle, and touch ellipse size. The values come directly from the underlying multitouch stream, so you can decide how much filtering or interpretation you want.

### Monitoring Every Trackpad

```swift
import Subsurface

let monitor = SubsurfaceMonitor()
monitor.start()

for await (device, contacts) in monitor.contacts() {
    print("\(device.name): \(contacts.count) contacts")
}
```

The monitor watches IOKit for multitouch devices as they appear and disappear. It is useful if you want to support built-in trackpads and Magic Trackpads without asking the caller to pick a device up front.

### Recognizing Gestures

```swift
import Subsurface

let monitor = SubsurfaceMonitor()
let recognizer = SubsurfaceGestureRecognizer(fingerCount: 2)

monitor.start()

for await event in recognizer.events(from: monitor) {
    switch event {
    case let .pan(pan):
        print("pan: \(pan.translation), velocity: \(pan.velocity)")

    case let .pinch(pinch):
        print("pinch: \(pinch.distance) from \(pinch.originDistance)")

    case let .rotation(rotation):
        print("rotation: \(rotation.rotation) radians")

    case let .determining(centroid, fingerCount):
        print("waiting on \(fingerCount) fingers at \(centroid)")

    case let .unresolvedEnded(reason):
        print("gesture ended before resolving: \(reason)")
    }
}
```

The recognizer starts in a determining phase, then locks onto the first gesture that crosses its threshold. Pinch wins first, then rotation, then pan. By default, once macOS recognizes a gesture, it lets the user lift or add fingers and continue the same gesture as long as at least two fingers remain on the surface. Subsurface matches that sticky behavior; set `requiresExactFingerCountToContinue` to `true` if a resolved gesture should end as soon as the active finger count differs from `fingerCount`.

You can tune the thresholds directly:

```swift
recognizer.minimumPanTranslation = 0.08
recognizer.minimumPinchDistance = 0.1
recognizer.minimumRotation = 0.15
recognizer.inactivityTimeout = .milliseconds(250)
```

### Haptic Feedback

```swift
import Subsurface

guard let actuator = SubsurfaceDevice.defaultDevice?.actuator else {
    return
}

actuator.open()
actuator.actuate(pattern: .click, intensity: 0.8)
actuator.close()
```

Subsurface includes the built-in feedback patterns that have been mapped so far, along with support for custom haptic patterns if you want to build your own waveform dictionary.

## Visualizer

The `Visualizer` folder contains a small SwiftUI app for seeing the raw touch stream. It can show contact ellipses and optionally, velocity vectors, contact metadata such as pressure, palm rejection, connected devices, and haptic feedback patterns. It is the easiest way to sanity-check what your trackpad is actually reporting before building against the library!

<div><video controls src="https://github.com/user-attachments/assets/343ab029-bd3e-4234-828e-26361115e3a5" muted="false"></video></div>

<div align="center">
  <em>The visualizer being used to show Loop's trackpad gestures.</em>
</div>

## License

Subsurface is released under the Apache-2.0 license. See the [LICENSE](LICENSE) file in the repository for the full license.
