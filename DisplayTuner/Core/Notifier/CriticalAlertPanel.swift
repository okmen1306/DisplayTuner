//
//  CriticalAlertPanel.swift
//  DisplayTuner
//
//  Görev: Kritik uyarı NSPanel'i.
//  Faz: 2  ·  Kararlar: 8.2  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

/// iPhone "Düşük Pil" tarzı, ekran ortasında, kendiliğinden kapanmayan uyarı.
@MainActor
final class CriticalAlertPanel {
    private var panel: NSPanel?

    func show(title: String, message: String) {
        panel?.close()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 270, height: 220),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true

        let host = NSHostingView(rootView: CriticalAlertView(title: title, message: message) { [weak self] in
            self?.dismiss()
        })
        host.layoutSubtreeIfNeeded()
        panel.setContentSize(host.fittingSize)
        panel.contentView = host

        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - panel.frame.width / 2, y: screen.midY - panel.frame.height / 2))
        }
        panel.orderFrontRegardless()
        NSSound(named: "Funk")?.play()
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
