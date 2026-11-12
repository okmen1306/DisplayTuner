//
//  CGSPrivate.swift
//  DisplayTuner
//
//  Görev: CGSSetCursorScale vb.
//  Faz: 4  ·  Kararlar: D-53, R8  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation

enum CGSPrivate {
    typealias ConnectionFn = @convention(c) () -> Int32
    typealias SetScaleFn = @convention(c) (Int32, Float) -> Int32
    typealias GetScaleFn = @convention(c) (Int32, UnsafeMutablePointer<Float>) -> Int32

    nonisolated(unsafe) private static let connection = PrivateSymbols.function("CGSMainConnectionID", as: ConnectionFn.self)
    nonisolated(unsafe) private static let setScale = PrivateSymbols.function("CGSSetCursorScale", as: SetScaleFn.self)
    nonisolated(unsafe) private static let getScale = PrivateSymbols.function("CGSGetCursorScale", as: GetScaleFn.self)

    // Mousecape'in kullandığı imza (MCPrivate.h).
    typealias RegisterFn = @convention(c) (Int32, UnsafePointer<CChar>, Bool, Bool, UInt, CFArray, CGSize, CGPoint,
                                           UnsafeMutablePointer<Int32>, CGRect, CGFloat, Int) -> Int32
    typealias RemoveFn = @convention(c) (Int32, UnsafePointer<CChar>, Bool) -> Int32
    nonisolated(unsafe) private static let register = PrivateSymbols.function("CGSRegisterCursorWithImages", as: RegisterFn.self)
    nonisolated(unsafe) private static let remove = PrivateSymbols.function("CGSRemoveRegisteredCursor", as: RemoveFn.self)

    static var canCustomizeCursor: Bool { connection != nil && register != nil && remove != nil }

    /// Sistem imlecini (ör. "com.apple.coregraphics.Arrow") verilen görüntüyle değiştirir; `size` nokta cinsinden.
    @discardableResult
    static func registerCursor(_ name: String, image: CGImage, size: CGSize, hotspot: CGPoint) -> Bool {
        guard let connection, let register else { return false }
        var seed: Int32 = 0
        let result = name.withCString {
            register(connection(), $0, true, true, 1, [image] as CFArray, size, hotspot, &seed,
                     CGRect(origin: .zero, size: size), 0, 0)
        }
        return result == 0
    }

    /// Kayıtlı özel imleci kaldırır; sistem varsayılanına döner.
    static func removeCursor(_ name: String) {
        guard let connection, let remove else { return }
        _ = name.withCString { remove(connection(), $0, false) }
    }

    static func cursorScale() -> Float? {
        guard let connection, let getScale else { return nil }
        var value: Float = 1
        return getScale(connection(), &value) == 0 ? value : nil
    }

    @discardableResult
    static func setCursorScale(_ scale: Float) -> Bool {
        guard let connection, let setScale else { return false }
        return setScale(connection(), min(max(scale, 1), 4)) == 0
    }
}
