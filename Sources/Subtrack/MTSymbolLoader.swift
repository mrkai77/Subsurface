//
//  MTSymbolLoader.swift
//  Subtrack
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation
import Scribe

@Loggable(style: .static)
private enum MTSymbolLoader {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? = {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            log.error("failed to open \(frameworkPath)")
            return nil
        }
        return handle
    }()

    static func load<T>(_ name: StaticString) -> T? {
        guard let handle else {
            log.error("No handle; cannot load symbol \(name)")
            return nil
        }

        // Clear any prior error
        dlerror()

        guard let sym = dlsym(handle, name.description) else {
            if let err = dlerror() {
                log.error("Failed to load symbol \(name): \(String(cString: err))")
            } else {
                log.error("Failed to load symbol \(name)")
            }
            return nil
        }

        return unsafeBitCast(sym, to: T.self)
    }
}

// MARK: - C API Bindings

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTActuatorRef = UnsafeMutableRawPointer
typealias MTActuationRef = UnsafeMutableRawPointer

// MARK: - Callback Types

typealias MTContactCallbackFunction = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    Int32,
    Double,
    Int32
) -> Int32

typealias MTFrameCallbackFunction = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    Int32,
    Double,
    Int32
) -> ()

typealias MTFrameCallbackFunctionWithRefcon = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    Int,
    Double,
    Int,
    UnsafeMutableRawPointer
) -> ()

typealias MTPathCallbackFunction = @convention(c) (
    MTDeviceRef,
    Int,
    Int,
    UnsafeMutableRawPointer
) -> ()

typealias MTPathCallbackFunctionWithRefcon = @convention(c) (
    MTDeviceRef,
    Int,
    Int32,
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer
) -> ()

typealias MTImageCallbackFunction = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer
) -> ()

// MARK: - C Function Declarations

// MARK: - Device Management

let MTDeviceGetTypeID: (@convention(c) () -> CFTypeID)? = MTSymbolLoader.load("MTDeviceGetTypeID")
let MTAbsoluteTimeGetCurrent: (@convention(c) () -> Double)? = MTSymbolLoader.load("MTAbsoluteTimeGetCurrent")
let MTDeviceIsAvailable: (@convention(c) () -> Bool)? = MTSymbolLoader.load("MTDeviceIsAvailable")
let MTDeviceCreateDefault: (@convention(c) () -> MTDeviceRef?)? = MTSymbolLoader.load("MTDeviceCreateDefault")
let MTDeviceCreateList: (@convention(c) () -> Unmanaged<CFMutableArray>?)? = MTSymbolLoader.load("MTDeviceCreateList")
let MTDeviceCreateFromDeviceID: (@convention(c) (UInt64) -> MTDeviceRef?)? = MTSymbolLoader.load("MTDeviceCreateFromDeviceID")
let MTDeviceCreateFromService: (@convention(c) (io_service_t) -> MTDeviceRef?)? = MTSymbolLoader.load("MTDeviceCreateFromService")
let MTDeviceRelease: (@convention(c) (MTDeviceRef) -> ())? = MTSymbolLoader.load("MTDeviceRelease")
let MTDeviceStart: (@convention(c) (MTDeviceRef, Int32) -> OSStatus)? = MTSymbolLoader.load("MTDeviceStart")
let MTDeviceStop: (@convention(c) (MTDeviceRef) -> OSStatus)? = MTSymbolLoader.load("MTDeviceStop")

// MARK: - Device State

let MTDeviceIsRunning: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceIsRunning")
let MTDeviceIsBuiltIn: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceIsBuiltIn")
let MTDeviceIsOpaqueSurface: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceIsOpaqueSurface")
let MTDeviceIsAlive: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceIsAlive")
let MTDeviceIsMTHIDDevice: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceIsMTHIDDevice")
let MTDeviceSupportsForce: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceSupportsForce")
let MTDeviceSupportsActuation: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceSupportsActuation")
let MTDeviceDriverIsReady: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceDriverIsReady")
let MTDevicePowerControlSupported: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDevicePowerControlSupported")

// MARK: - Device Properties

let MTDeviceGetService: (@convention(c) (MTDeviceRef) -> io_service_t)? = MTSymbolLoader.load("MTDeviceGetService")
let MTDeviceGetSensorSurfaceDimensions: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetSensorSurfaceDimensions")
let MTDeviceGetSensorDimensions: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetSensorDimensions")
let MTDeviceGetFamilyID: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetFamilyID")
let MTDeviceGetDeviceID: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetDeviceID")
let MTDeviceGetVersion: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetVersion")
let MTDeviceGetDriverType: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetDriverType")
let MTDeviceGetTransportMethod: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetTransportMethod")
let MTDeviceGetSerialNumber: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<CFString?>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceGetSerialNumber")

// MARK: - Image and Debug

let MTPrintImageRegionDescriptors: (@convention(c) (MTDeviceRef) -> ())? = MTSymbolLoader.load("MTPrintImageRegionDescriptors")

// MARK: - Force Response

let MTDeviceGetSystemForceResponseEnabled: (@convention(c) (MTDeviceRef) -> Bool)? = MTSymbolLoader.load("MTDeviceGetSystemForceResponseEnabled")
let MTDeviceSetSystemForceResponseEnabled: (@convention(c) (MTDeviceRef, Bool) -> ())? = MTSymbolLoader.load("MTDeviceSetSystemForceResponseEnabled")
let MTDeviceSupportsSilentClick: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Bool>) -> OSStatus)? = MTSymbolLoader.load("MTDeviceSupportsSilentClick")

// MARK: - Power Management

let MTDevicePowerSetEnabled: (@convention(c) (MTDeviceRef, Bool) -> OSStatus)? = MTSymbolLoader.load("MTDevicePowerSetEnabled")
let MTDevicePowerGetEnabled: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Bool>) -> ())? = MTSymbolLoader.load("MTDevicePowerGetEnabled")

// MARK: - Run Loop

let MTDeviceCreateMultitouchRunLoopSource: (@convention(c) (MTDeviceRef) -> CFRunLoopSource?)? = MTSymbolLoader.load("MTDeviceCreateMultitouchRunLoopSource")
let MTDeviceScheduleOnRunLoop: (@convention(c) (MTDeviceRef, CFRunLoop, CFString) -> OSStatus)? = MTSymbolLoader.load("MTDeviceScheduleOnRunLoop")

// MARK: - Utilities

let MTEasyInstallPrintCallbacks: (@convention(c) (MTDeviceRef, Bool, Bool, Bool, Bool, Bool, Bool) -> ())? = MTSymbolLoader.load("MTEasyInstallPrintCallbacks")
let MTGetPathStageName: (@convention(c) (Int32) -> UnsafeMutablePointer<CChar>?)? = MTSymbolLoader.load("MTGetPathStageName")

// MARK: - Contact Frame Callbacks

let MTRegisterContactFrameCallback: (@convention(c) (MTDeviceRef, MTContactCallbackFunction?) -> ())? = MTSymbolLoader.load("MTRegisterContactFrameCallback")
let MTUnregisterContactFrameCallback: (@convention(c) (MTDeviceRef, MTContactCallbackFunction?) -> ())? = MTSymbolLoader.load("MTUnregisterContactFrameCallback")
let MTRegisterContactFrameCallbackWithRefcon: (@convention(c) (MTDeviceRef, MTFrameCallbackFunctionWithRefcon?, UnsafeMutableRawPointer?) -> Bool)? = MTSymbolLoader.load("MTRegisterContactFrameCallbackWithRefcon")

// MARK: - Full Frame Callbacks

let MTRegisterFullFrameCallback: (@convention(c) (MTDeviceRef, MTFrameCallbackFunction?) -> ())? = MTSymbolLoader.load("MTRegisterFullFrameCallback")
let MTUnregisterFullFrameCallback: (@convention(c) (MTDeviceRef, MTFrameCallbackFunction?) -> ())? = MTSymbolLoader.load("MTUnregisterFullFrameCallback")

// MARK: - Path Callbacks

let MTRegisterPathCallback: (@convention(c) (MTDeviceRef, MTPathCallbackFunction?) -> ())? = MTSymbolLoader.load("MTRegisterPathCallback")
let MTUnregisterPathCallback: (@convention(c) (MTDeviceRef, MTPathCallbackFunction?) -> ())? = MTSymbolLoader.load("MTUnregisterPathCallback")
let MTRegisterPathCallbackWithRefcon: (@convention(c) (MTDeviceRef, MTPathCallbackFunctionWithRefcon?, UnsafeMutableRawPointer?) -> Bool)? = MTSymbolLoader.load("MTRegisterPathCallbackWithRefcon")
let MTUnregisterPathCallbackWithRefcon: (@convention(c) (MTDeviceRef, MTPathCallbackFunctionWithRefcon?) -> Bool)? = MTSymbolLoader.load("MTUnregisterPathCallbackWithRefcon")

// MARK: - Image Callbacks

let MTRegisterImageCallbackWithRefcon: (@convention(c) (MTDeviceRef, MTImageCallbackFunction?, Int32, Int32, UnsafeMutableRawPointer?) -> Bool)? = MTSymbolLoader.load("MTRegisterImageCallbackWithRefcon")
let MTRegisterImageCallback: (@convention(c) (MTDeviceRef, MTImageCallbackFunction?, Int32, Int32) -> Bool)? = MTSymbolLoader.load("MTRegisterImageCallback")
let MTUnregisterImageCallback: (@convention(c) (MTDeviceRef, MTImageCallbackFunction?) -> Bool)? = MTSymbolLoader.load("MTUnregisterImageCallback")
let MTRegisterMultitouchImageCallback: (@convention(c) (MTDeviceRef, MTImageCallbackFunction?) -> Bool)? = MTSymbolLoader.load("MTRegisterMultitouchImageCallback")

// MARK: - Actuator

let MTDeviceGetMTActuator: (@convention(c) (MTDeviceRef) -> MTActuatorRef?)? = MTSymbolLoader.load("MTDeviceGetMTActuator")
let MTActuatorGetSystemActuationsEnabled: (@convention(c) (MTActuatorRef) -> Bool)? = MTSymbolLoader.load("MTActuatorGetSystemActuationsEnabled")
let MTActuatorSetSystemActuationsEnabled: (@convention(c) (MTActuatorRef, Bool) -> OSStatus)? = MTSymbolLoader.load("MTActuatorSetSystemActuationsEnabled")
let MTActuatorCreateFromDeviceID: (@convention(c) (UInt64) -> MTActuatorRef?)? = MTSymbolLoader.load("MTActuatorCreateFromDeviceID")
let MTActuatorOpen: (@convention(c) (MTActuatorRef) -> IOReturn)? = MTSymbolLoader.load("MTActuatorOpen")
let MTActuatorClose: (@convention(c) (MTActuatorRef) -> IOReturn)? = MTSymbolLoader.load("MTActuatorClose")
let MTActuatorActuate: (@convention(c) (MTActuatorRef, Int32, UInt32, Float, Float) -> IOReturn)? = MTSymbolLoader.load("MTActuatorActuate")
let MTActuatorIsOpen: (@convention(c) (MTActuatorRef) -> Bool)? = MTSymbolLoader.load("MTActuatorIsOpen")

// MARK: - Actuation

let MTActuationActuate: (@convention(c) (MTActuationRef, MTActuatorRef, UInt32) -> IOReturn)? = MTSymbolLoader.load("MTActuationActuate")
let MTActuationCreateFromDictionary: (@convention(c) (CFDictionary, MTActuatorRef) -> MTActuationRef?)? = MTSymbolLoader.load("MTActuationCreateFromDictionary")
