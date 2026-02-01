//
//  PrivateAPIs.swift
//  MultitouchSupportKit
//
//  Created by Kai Azim on 2026-01-31.
//

import Foundation

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

@_silgen_name("MTDeviceGetTypeID")
func MTDeviceGetTypeID() -> CFTypeID

@_silgen_name("MTAbsoluteTimeGetCurrent")
func MTAbsoluteTimeGetCurrent() -> Double

@_silgen_name("MTDeviceIsAvailable")
func MTDeviceIsAvailable() -> Bool

@_silgen_name("MTDeviceCreateDefault")
func MTDeviceCreateDefault() -> MTDeviceRef?

@_silgen_name("MTDeviceCreateList")
func MTDeviceCreateList() -> Unmanaged<CFMutableArray>?

@_silgen_name("MTDeviceCreateFromDeviceID")
func MTDeviceCreateFromDeviceID(_ deviceID: UInt64) -> MTDeviceRef?

@_silgen_name("MTDeviceCreateFromService")
func MTDeviceCreateFromService(_ service: io_service_t) -> MTDeviceRef?

@_silgen_name("MTDeviceCreateFromGUID")
func MTDeviceCreateFromGUID(_ guid: uuid_t) -> MTDeviceRef?

@_silgen_name("MTDeviceRelease")
func MTDeviceRelease(_ device: MTDeviceRef)

@_silgen_name("MTDeviceStart")
func MTDeviceStart(_ device: MTDeviceRef, _ mode: Int32) -> OSStatus

@_silgen_name("MTDeviceStop")
func MTDeviceStop(_ device: MTDeviceRef) -> OSStatus

@_silgen_name("MTDeviceIsRunning")
func MTDeviceIsRunning(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceIsBuiltIn")
func MTDeviceIsBuiltIn(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceIsOpaqueSurface")
func MTDeviceIsOpaqueSurface(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceIsAlive")
func MTDeviceIsAlive(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceIsMTHIDDevice")
func MTDeviceIsMTHIDDevice(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceSupportsForce")
func MTDeviceSupportsForce(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceSupportsActuation")
func MTDeviceSupportsActuation(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceDriverIsReady")
func MTDeviceDriverIsReady(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDevicePowerControlSupported")
func MTDevicePowerControlSupported(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceGetService")
func MTDeviceGetService(_ device: MTDeviceRef) -> io_service_t

@_silgen_name("MTDeviceGetSensorSurfaceDimensions")
func MTDeviceGetSensorSurfaceDimensions(_ device: MTDeviceRef, _ width: UnsafeMutablePointer<Int32>, _ height: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetSensorDimensions")
func MTDeviceGetSensorDimensions(_ device: MTDeviceRef, _ rows: UnsafeMutablePointer<Int32>, _ cols: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetFamilyID")
func MTDeviceGetFamilyID(_ device: MTDeviceRef, _ familyID: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetDeviceID")
func MTDeviceGetDeviceID(_ device: MTDeviceRef, _ deviceID: UnsafeMutablePointer<UInt64>) -> OSStatus

@_silgen_name("MTDeviceGetVersion")
func MTDeviceGetVersion(_ device: MTDeviceRef, _ version: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetDriverType")
func MTDeviceGetDriverType(_ device: MTDeviceRef, _ driverType: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetTransportMethod")
func MTDeviceGetTransportMethod(_ device: MTDeviceRef, _ transportMethod: UnsafeMutablePointer<Int32>) -> OSStatus

@_silgen_name("MTDeviceGetGUID")
func MTDeviceGetGUID(_ device: MTDeviceRef, _ guid: UnsafeMutablePointer<uuid_t>) -> OSStatus

@_silgen_name("MTDeviceGetSerialNumber")
func MTDeviceGetSerialNumber(_ device: MTDeviceRef, _ serialNumber: UnsafeMutablePointer<CFString?>) -> OSStatus

@_silgen_name("MTPrintImageRegionDescriptors")
func MTPrintImageRegionDescriptors(_ device: MTDeviceRef)

@_silgen_name("MTDeviceGetSystemForceResponseEnabled")
func MTDeviceGetSystemForceResponseEnabled(_ device: MTDeviceRef) -> Bool

@_silgen_name("MTDeviceSetSystemForceResponseEnabled")
func MTDeviceSetSystemForceResponseEnabled(_ device: MTDeviceRef, _ enabled: Bool)

@_silgen_name("MTDeviceSupportsSilentClick")
func MTDeviceSupportsSilentClick(_ device: MTDeviceRef, _ supported: UnsafeMutablePointer<Bool>) -> OSStatus

@_silgen_name("MTDevicePowerSetEnabled")
func MTDevicePowerSetEnabled(_ device: MTDeviceRef, _ enabled: Bool) -> OSStatus

@_silgen_name("MTDevicePowerGetEnabled")
func MTDevicePowerGetEnabled(_ device: MTDeviceRef, _ enabled: UnsafeMutablePointer<Bool>)

@_silgen_name("MTDeviceCreateMultitouchRunLoopSource")
func MTDeviceCreateMultitouchRunLoopSource(_ device: MTDeviceRef) -> CFRunLoopSource?

@_silgen_name("MTDeviceScheduleOnRunLoop")
func MTDeviceScheduleOnRunLoop(_ device: MTDeviceRef, _ runLoop: CFRunLoop, _ mode: CFString) -> OSStatus

@_silgen_name("MTEasyInstallPrintCallbacks")
func MTEasyInstallPrintCallbacks(_ device: MTDeviceRef, _ path: Bool, _ img1: Bool, _ img2: Bool, _ img3: Bool, _ img4: Bool, _ img5: Bool)

@_silgen_name("MTGetPathStageName")
func MTGetPathStageName(_ state: Int32) -> UnsafeMutablePointer<CChar>?

@_silgen_name("MTRegisterContactFrameCallback")
func MTRegisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallbackFunction?)

@_silgen_name("MTUnregisterContactFrameCallback")
func MTUnregisterContactFrameCallback(_ device: MTDeviceRef, _ callback: MTContactCallbackFunction?)

@_silgen_name("MTRegisterContactFrameCallbackWithRefcon")
func MTRegisterContactFrameCallbackWithRefcon(_ device: MTDeviceRef, _ callback: MTFrameCallbackFunctionWithRefcon?, _ refcon: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("MTRegisterFullFrameCallback")
func MTRegisterFullFrameCallback(_ device: MTDeviceRef, _ callback: MTFrameCallbackFunction?)

@_silgen_name("MTUnregisterFullFrameCallback")
func MTUnregisterFullFrameCallback(_ device: MTDeviceRef, _ callback: MTFrameCallbackFunction?)

@_silgen_name("MTRegisterPathCallback")
func MTRegisterPathCallback(_ device: MTDeviceRef, _ callback: MTPathCallbackFunction?)

@_silgen_name("MTUnregisterPathCallback")
func MTUnregisterPathCallback(_ device: MTDeviceRef, _ callback: MTPathCallbackFunction?)

@_silgen_name("MTRegisterPathCallbackWithRefcon")
func MTRegisterPathCallbackWithRefcon(_ device: MTDeviceRef, _ callback: MTPathCallbackFunctionWithRefcon?, _ refcon: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("MTUnregisterPathCallbackWithRefcon")
func MTUnregisterPathCallbackWithRefcon(_ device: MTDeviceRef, _ callback: MTPathCallbackFunctionWithRefcon?) -> Bool

@_silgen_name("MTRegisterImageCallbackWithRefcon")
func MTRegisterImageCallbackWithRefcon(_ device: MTDeviceRef, _ callback: MTImageCallbackFunction?, _ arg1: Int32, _ arg2: Int32, _ refcon: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("MTRegisterImageCallback")
func MTRegisterImageCallback(_ device: MTDeviceRef, _ callback: MTImageCallbackFunction?, _ arg1: Int32, _ arg2: Int32) -> Bool

@_silgen_name("MTUnregisterImageCallback")
func MTUnregisterImageCallback(_ device: MTDeviceRef, _ callback: MTImageCallbackFunction?) -> Bool

@_silgen_name("MTRegisterMultitouchImageCallback")
func MTRegisterMultitouchImageCallback(_ device: MTDeviceRef, _ callback: MTImageCallbackFunction?) -> Bool

@_silgen_name("MTDeviceGetMTActuator")
func MTDeviceGetMTActuator(_ device: MTDeviceRef) -> MTActuatorRef?

@_silgen_name("MTActuatorGetSystemActuationsEnabled")
func MTActuatorGetSystemActuationsEnabled(_ actuator: MTActuatorRef) -> Bool

@_silgen_name("MTActuatorSetSystemActuationsEnabled")
func MTActuatorSetSystemActuationsEnabled(_ actuator: MTActuatorRef, _ enabled: Bool) -> OSStatus

@_silgen_name("MTActuatorCreateFromDeviceID")
func MTActuatorCreateFromDeviceID(_ deviceID: UInt64) -> MTActuatorRef?

@_silgen_name("MTActuatorOpen")
func MTActuatorOpen(_ actuator: MTActuatorRef) -> IOReturn

@_silgen_name("MTActuatorClose")
func MTActuatorClose(_ actuator: MTActuatorRef) -> IOReturn

@_silgen_name("MTActuatorActuate")
func MTActuatorActuate(_ actuator: MTActuatorRef, _ actuationID: Int32, _ flags: UInt32, _ scale1: Float, _ scale2: Float) -> IOReturn

@_silgen_name("MTActuationActuate")
func MTActuationActuate(_ actuation: MTActuationRef, _ actuator: MTActuatorRef, _ flags: UInt32) -> IOReturn

@_silgen_name("MTActuationCreateFromDictionary")
func MTActuationCreateFromDictionary(_ dict: CFDictionary, _ actuator: MTActuatorRef) -> MTActuationRef?

@_silgen_name("MTActuatorIsOpen")
func MTActuatorIsOpen(_ actuator: MTActuatorRef) -> Bool
