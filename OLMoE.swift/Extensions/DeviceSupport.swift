//
//  DeviceSupport.swift
//  OLMoE.swift
//
//  Created by Ken Adamson on 11/15/24.
//


import SwiftUI
import os

func deviceHasEnoughRam() -> Bool {
    let requiredRAM: UInt64 = 6 * 1024 * 1024 * 1024
    let totalRAM = ProcessInfo.processInfo.physicalMemory
    print("Total RAM (GB)", totalRAM / (1024 * 1024 * 1024))
    return totalRAM >= requiredRAM
}

// Device support check function
func isDeviceSupported() -> Bool {
    #if targetEnvironment(simulator)
    return true
    #elseif targetEnvironment(macCatalyst)
    return true
    #else
    return deviceHasEnoughRam()
    #endif
}

#if canImport(UIKit)
import UIKit

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "unknown"
    }
}
#endif

// SwiftUI View for unsupported devices

