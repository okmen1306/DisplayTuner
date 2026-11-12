//
//  HUDPanel.swift
//  DisplayTuner
//
//  Görev: HUD NSPanel'i (üst orta, 2 sn).
//  Faz: 2  ·  Kararlar: 8.3  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

/// Dynamic Island tarzı kapsül; menü bar'ın hemen altında, tıklamaları geçirir.
@MainActor
final class HUDPanel {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(symbol: String, text: String) {
        hideTask?.cancel()
        panel?.close()

        let width: CGFloat = 360
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 36),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: HUDView(symbol: symbol, text: text))

        if let screen = NSScreen.main {
            let top = screen.visibleFrame.maxY - 8
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - width / 2, y: top - 36))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.panel?.close()
            self?.panel = nil
        }
    }
}
