//
//  MainWindowController.swift
//  DisplayTuner
//
//  Görev: Ana pencereyi oluşturur/öne getirir (NSWindow + NSHostingController).
//  Faz: 1  ·  Kararlar: D-21, D-22  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    let state = MainWindowState()
    private let services: AppServices
    private var window: NSWindow?

    init(services: AppServices) {
        self.services = services
    }

    /// D-137: pencere açıkken Dock ve ⌘Tab'da ikonla görünür; kapanınca menü bar uygulamasına döner (D-07).
    func show(_ item: SidebarItem? = nil) {
        if let item { state.selection = item }
        let window = window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DisplayTuner"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentViewController = NSHostingController(rootView: MainWindowView(state: state, services: services))
        window.setFrameAutosaveName("DisplayTunerMainWindow")
        if !window.setFrameUsingName("DisplayTunerMainWindow") { window.center() }
        return window
    }
}
