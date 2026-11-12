//
//  DisplayServicesBridge.swift
//  DisplayTuner
//
//  Görev: DisplayServicesGet/SetBrightness.
//  Faz: 1  ·  Kararlar: 7.1  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation

/// Dahili ekran parlaklığı için private DisplayServices köprüsü.
final class DisplayServicesBridge: @unchecked Sendable {
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static let shared = DisplayServicesBridge()

    private let getBrightness: GetFn?
    private let setBrightness: SetFn?

    private init() {
        PrivateSymbols.loadFramework("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices")
        getBrightness = PrivateSymbols.function("DisplayServicesGetBrightness", as: GetFn.self)
        setBrightness = PrivateSymbols.function("DisplayServicesSetBrightness", as: SetFn.self)
    }

    func brightness(of display: CGDirectDisplayID) -> Float? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    @discardableResult
    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(display, min(max(value, 0), 1)) == 0
    }
}
