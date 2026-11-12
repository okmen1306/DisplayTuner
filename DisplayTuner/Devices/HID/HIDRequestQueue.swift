//
//  HIDRequestQueue.swift
//  DisplayTuner
//
//  Görev: Cihaz başına FIFO istek kuyruğu.
//  Faz: 2  ·  Kararlar: D-60  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Actor yeniden girişinde (reentrancy) isteklerin karışmaması için seri çalıştırıcı.
/// Bir istek bitmeden diğeri başlamaz (D-60).
actor HIDRequestQueue {
    private var tail: Task<Void, Never>?

    func run<T: Sendable>(_ operation: @escaping @Sendable () async -> T) async -> T {
        let previous = tail
        let task = Task<T, Never> {
            await previous?.value
            return await operation()
        }
        tail = Task { _ = await task.value }
        return await task.value
    }
}
