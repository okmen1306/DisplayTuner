//
//  StatusItemController.swift
//  DisplayTuner
//
//  Görev: NSStatusItem: tek tık popover, çift tık ana pencere, sağ tık menü; pil uyarı noktası.
//  Faz: 1  ·  Kararlar: D-20, D-21  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let brightness = BrightnessModel()
    private let mainWindow: MainWindowController

    private let notifier: Notifier

    init(mainWindow: MainWindowController, services: AppServices) {
        self.mainWindow = mainWindow
        self.notifier = services.notifier
        super.init()

        popover.behavior = .transient
        // Parlaklık değerleri önceden okunur; popover ilk açılışta boş/zıplayan içerikle gelmez (D-154).
        Task { [brightness] in await brightness.load() }
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: QuickPopoverView(brightness: brightness, batteries: services.batteries, profiles: services.profiles,
                                       onOpenDevice: { [weak self] item in
                                           self?.popover.performClose(nil)
                                           self?.mainWindow.show(item)
                                       }) { [weak self] in
                self?.popover.performClose(nil)
                self?.mainWindow.show()
            }
        )

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "DisplayTuner")
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    /// D-21: tek tık popover, çift tık pencere, sağ tık menü.
    /// D-154: popover ilk tıkta (mouse down) hemen açılır; çift tıkı beklemek ~0,5 sn gecikme yaratıyordu.
    /// İkinci tık gelirse popover kapanır ve ana pencere açılır.
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            popover.performClose(nil)
            showMenu()
            return
        }
        if event.clickCount >= 2 {
            popover.performClose(nil)
            mainWindow.show()
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Ana Pencereyi Aç"), action: #selector(openMainWindow), keyEquivalent: "").target = self
        // Profiller alt menüsü Faz 5'te eklenecek.
        menu.addItem(withTitle: String(localized: "Örnek Bildirimleri Göster"), action: #selector(showSampleNotifications), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "DisplayTuner'dan Çık"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openMainWindow() {
        mainWindow.show()
    }

    @objc private func showSampleNotifications() {
        notifier.showSamples()
    }
}
