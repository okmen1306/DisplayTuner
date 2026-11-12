//
//  IOHIDEventSystemBridge.swift
//  DisplayTuner
//
//  Görev: IOHIDEventSystemClient (imleç hızı, ivme).
//  Faz: 4  ·  Kararlar: D-52, R8  (bkz. AGENT_BRIEF.md)
//

import Foundation

final class IOHIDEventSystemBridge: @unchecked Sendable {
    typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    typealias SetFn = @convention(c) (AnyObject, CFString, CFTypeRef) -> Bool
    typealias CopyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<CFTypeRef>?

    static let shared = IOHIDEventSystemBridge()
    private let client: AnyObject?
    private let setFn: SetFn?
    private let copyFn: CopyFn?

    private init() {
        let create = PrivateSymbols.function("IOHIDEventSystemClientCreateSimpleClient", as: CreateFn.self)
        client = create?(kCFAllocatorDefault)?.takeRetainedValue()
        setFn = PrivateSymbols.function("IOHIDEventSystemClientSetProperty", as: SetFn.self)
        copyFn = PrivateSymbols.function("IOHIDEventSystemClientCopyProperty", as: CopyFn.self)
    }

    var isAvailable: Bool { client != nil && setFn != nil }

    @discardableResult
    func set(_ key: String, _ value: CFTypeRef) -> Bool {
        guard let client, let setFn else { return false }
        return setFn(client, key as CFString, value)
    }

    func number(_ key: String) -> Double? {
        guard let client, let copyFn, let value = copyFn(client, key as CFString)?.takeRetainedValue() else { return nil }
        return (value as? NSNumber)?.doubleValue
    }
}
