//
//  ModeService.swift
//  DisplayTuner
//
//  Görev: Çözünürlük, HiDPI, Hz.
//  Faz: 5  ·  Kararlar: D-40, D-126  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation
import os

@MainActor
enum ModeService {
    private static let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Mode")

    private static func allModes(_ id: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        return (CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode]) ?? []
    }

    /// Görünür boyut + piksel boyutu (HiDPI = piksel > görünür).
    struct Resolution: Hashable, Sendable {
        let width: Int, height: Int, pixelWidth: Int
        var isHiDPI: Bool { pixelWidth > width }
        var label: String { "\(width) × \(height)\(isHiDPI ? " (HiDPI)" : "")" }
    }

    /// Masaüstü için kullanılabilir çözünürlükler; HiDPI önce, büyükten küçüğe.
    static func resolutions(_ id: CGDirectDisplayID) -> [Resolution] {
        let set = Set(allModes(id).filter { $0.isUsableForDesktopGUI() }
            .map { Resolution(width: $0.width, height: $0.height, pixelWidth: $0.pixelWidth) })
        return set.sorted { ($0.isHiDPI ? 1 : 0, $0.width, $0.pixelWidth) > ($1.isHiDPI ? 1 : 0, $1.width, $1.pixelWidth) }
    }

    static func currentResolution(_ id: CGDirectDisplayID) -> Resolution? {
        CGDisplayCopyDisplayMode(id).map { Resolution(width: $0.width, height: $0.height, pixelWidth: $0.pixelWidth) }
    }

    static func refreshRates(for r: Resolution, on id: CGDirectDisplayID) -> [Int] {
        Array(Set(allModes(id).filter { $0.width == r.width && $0.height == r.height && $0.pixelWidth == r.pixelWidth }
            .map { Int($0.refreshRate.rounded()) })).sorted()
    }

    /// Monitörün herhangi bir masaüstü çözünürlüğünde sunduğu bütün Hz değerleri (D-144).
    static func allRefreshRates(_ id: CGDirectDisplayID) -> [Int] {
        Array(Set(allModes(id).filter { $0.isUsableForDesktopGUI() }.map { Int($0.refreshRate.rounded()) })).sorted()
    }

    /// İstenen Hz için en uygun çözünürlük: önce mevcut, sonra aynı görünür boyut (HiDPI önce), sonra en büyüğü.
    static func bestResolution(for hz: Int, preferring current: Resolution, on id: CGDirectDisplayID) -> Resolution? {
        let candidates = resolutions(id).filter { refreshRates(for: $0, on: id).contains(hz) }
        return candidates.first { $0 == current }
            ?? candidates.first { $0.width == current.width && $0.height == current.height }
            ?? candidates.first
    }

    /// Çözünürlük + Hz. İstenen Hz yoksa o çözünürlükteki en yakın Hz seçilir.
    @discardableResult
    static func set(_ r: Resolution, hz: Int, on id: CGDirectDisplayID) -> Int? {
        let candidates = allModes(id).filter { $0.width == r.width && $0.height == r.height && $0.pixelWidth == r.pixelWidth }
        guard let target = candidates.min(by: { abs(Int($0.refreshRate.rounded()) - hz) < abs(Int($1.refreshRate.rounded()) - hz) }) else { return nil }
        guard CGDisplaySetDisplayMode(id, target, nil) == .success else { return nil }
        let applied = Int(target.refreshRate.rounded())
        logger.info("Mod: \(r.label, privacy: .public) @\(applied) Hz")
        return applied
    }

    static func currentRefreshRate(_ id: CGDirectDisplayID) -> Int? {
        CGDisplayCopyDisplayMode(id).map { Int($0.refreshRate.rounded()) }
    }

    /// Mevcut çözünürlükte (aynı görünür ve piksel boyutu) monitörün o an sunduğu Hz değerleri (D-40).
    static func refreshRates(_ id: CGDirectDisplayID) -> [Int] {
        guard let current = CGDisplayCopyDisplayMode(id) else { return [] }
        let rates = allModes(id)
            .filter { $0.width == current.width && $0.height == current.height && $0.pixelWidth == current.pixelWidth }
            .map { Int($0.refreshRate.rounded()) }
        return Array(Set(rates)).sorted()
    }

    /// Çözünürlüğü koruyarak Hz değiştirir.
    @discardableResult
    static func setRefreshRate(_ hz: Int, on id: CGDirectDisplayID) -> Bool {
        guard let current = CGDisplayCopyDisplayMode(id) else { return false }
        if Int(current.refreshRate.rounded()) == hz { return true }
        guard let target = allModes(id).first(where: {
            $0.width == current.width && $0.height == current.height && $0.pixelWidth == current.pixelWidth
                && Int($0.refreshRate.rounded()) == hz
        }) else {
            logger.info("\(hz) Hz bu çözünürlükte yok")
            return false
        }
        let ok = CGDisplaySetDisplayMode(id, target, nil) == .success
        logger.info("Yenileme hızı \(hz) Hz: \(ok ? "uygulandı" : "başarısız", privacy: .public)")
        return ok
    }
}
