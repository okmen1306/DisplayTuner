//
//  MouseButtonMapper.swift
//  DisplayTuner
//
//  Görev: Mouse yan tuşları (3 = geri, 4 = ileri) → Geri/İleri ve diğer kısayollar (makro başlangıcı).
//  Kararlar: D-156  (bkz. AGENT_BRIEF.md)
//
//  CGEventTap ile `otherMouseDown/Up` yakalanır; atanmış tuşların olayı yutulur ve ön plandaki uygulamaya
//  klavye kısayolu gönderilir. Ters kaydırmayla aynı Erişilebilirlik iznini kullanır; yeni izin istemez.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import os

@MainActor
@Observable
final class MouseButtonMapper {
    enum Action: String, CaseIterable, Identifiable, Sendable {
        case back, forward, missionControl, appExpose, showDesktop, launchpad, prevSpace, nextSpace, closeTab, newTab, none
        var id: String { rawValue }

        /// Orta tuş için anlamlı olanlar önce (hareketler).
        static let gestureFirst: [Action] = [.none, .missionControl, .appExpose, .showDesktop, .launchpad,
                                             .prevSpace, .nextSpace, .back, .forward, .closeTab, .newTab]

        var title: String {
            switch self {
            case .back: String(localized: "Geri")
            case .forward: String(localized: "İleri")
            case .missionControl: String(localized: "Mission Control (3 parmak yukarı)")
            case .appExpose: String(localized: "Uygulama pencereleri (3 parmak aşağı)")
            case .showDesktop: String(localized: "Masaüstünü göster")
            case .launchpad: String(localized: "Uygulamalar (Launchpad)")
            case .prevSpace: String(localized: "Önceki masaüstü")
            case .nextSpace: String(localized: "Sonraki masaüstü")
            case .closeTab: String(localized: "Sekmeyi kapat")
            case .newTab: String(localized: "Yeni sekme")
            case .none: String(localized: "Varsayılan (değiştirme)")
            }
        }

        /// (tuş kodu, değiştiriciler)
        var shortcut: (CGKeyCode, CGEventFlags)? {
            switch self {
            case .back: (CGKeyCode(kVK_ANSI_LeftBracket), .maskCommand)
            case .forward: (CGKeyCode(kVK_ANSI_RightBracket), .maskCommand)
            case .missionControl, .appExpose, .showDesktop, .launchpad: nil   // uygulama başlatılarak (bkz. run)
            case .prevSpace: (CGKeyCode(kVK_LeftArrow), .maskControl)
            case .nextSpace: (CGKeyCode(kVK_RightArrow), .maskControl)
            case .closeTab: (CGKeyCode(kVK_ANSI_W), .maskCommand)
            case .newTab: (CGKeyCode(kVK_ANSI_T), .maskCommand)
            case .none: nil
            }
        }

        /// D-163: Mission Control vb. Dock'a doğrudan bildirimle açılır (BetterTouchTool'un yolu);
        /// klavye kısayolu ayarlarından bağımsızdır. Mission Control ikilisini başlatmak bu macOS'ta çalışmıyordu.
        nonisolated func run() {
            if let (key, flags) = shortcut { MouseButtonMapper.post(key: key, flags: flags); return }
            switch self {
            case .missionControl: Self.dock("com.apple.expose.awake")
            case .appExpose: Self.dock("com.apple.expose.front.awake")
            case .showDesktop: Self.dock("com.apple.showdesktop.awake")
            case .launchpad:
                if !Self.dock("com.apple.launchpad.toggle") || FileManager.default.fileExists(atPath: "/System/Applications/Apps.app") {
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    p.arguments = [FileManager.default.fileExists(atPath: "/System/Applications/Apps.app")
                                   ? "/System/Applications/Apps.app" : "/System/Applications/Launchpad.app"]
                    try? p.run()
                }
            default: break
            }
        }

        private typealias DockNotify = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void
        nonisolated(unsafe) private static let dockNotify: DockNotify? = {
            let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
            guard let symbol = dlsym(handle, "CoreDockSendNotification") else { return nil }
            return unsafeBitCast(symbol, to: DockNotify.self)
        }()

        @discardableResult
        private nonisolated static func dock(_ name: String) -> Bool {
            guard let dockNotify else { return false }
            dockNotify(name as CFString, nil)
            return true
        }

        var isRunnable: Bool { self != .none }
    }

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Buttons")

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "sideButtons.enabled"); isEnabled ? start() : stop() }
    }
    /// Tuş 3 (genelde arka yan tuş) ve tuş 4 (ön yan tuş).
    var button3: Action { didSet { defaults.set(button3.rawValue, forKey: "sideButtons.b3"); publish() } }
    var button4: Action { didSet { defaults.set(button4.rawValue, forKey: "sideButtons.b4"); publish() } }
    /// Orta tuş (tekerleğe basma). Varsayılan: değiştirme (normal orta tık).
    var button2: Action { didSet { defaults.set(button2.rawValue, forKey: "sideButtons.b2"); publish() } }
    /// Ayarlar sayfasında "tuşa bas" testi için son basılan tuş.
    private(set) var lastPressed: Int?
    /// Her basışta artar (önizlemede tuşu yakmak için).
    private(set) var pressTick = 0
    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var watchdog: Task<Void, Never>?

    /// Event tap geri çağrısı ana iş parçacığında çalışır; eşleme tablosu burada tutulur.
    nonisolated(unsafe) static var mapping: [Int64: Action] = [:]

    init() {
        isEnabled = defaults.object(forKey: "sideButtons.enabled") as? Bool ?? true
        button3 = Action(rawValue: defaults.string(forKey: "sideButtons.b3") ?? "") ?? .back
        button4 = Action(rawValue: defaults.string(forKey: "sideButtons.b4") ?? "") ?? .forward
        button2 = Action(rawValue: defaults.string(forKey: "sideButtons.b2") ?? "") ?? .none
        publish()
    }

    private func publish() {
        var map: [Int64: Action] = [:]
        if button3 != .none { map[3] = button3 }
        if button4 != .none { map[4] = button4 }
        if button2 != .none { map[2] = button2 }
        Self.mapping = map
    }

    /// İzin gelir gelmez başlar (izin istemez; izin akışı Mouse sayfasında).
    func startIfEnabled() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isEnabled, !self.isRunning, AXIsProcessTrusted() { self.start() }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue) | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput, let refcon {
                let mapper = Unmanaged<MouseButtonMapper>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { mapper.reenable() }
                return Unmanaged.passUnretained(event)
            }
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            if type == .otherMouseDown, let refcon {
                let mapper = Unmanaged<MouseButtonMapper>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { mapper.lastPressed = Int(button); mapper.pressTick += 1 }
            }
            guard let action = MouseButtonMapper.mapping[button] else {
                return Unmanaged.passUnretained(event)
            }
            if type == .otherMouseDown {
                action.run()
            }
            return nil   // atanmış tuşun orijinal olayı yutulur
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            logger.error("Yan tuş event tap'i oluşturulamadı")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        isRunning = true
        logger.info("Yan tuşlar açık")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isRunning = false
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    nonisolated static func post(key: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
