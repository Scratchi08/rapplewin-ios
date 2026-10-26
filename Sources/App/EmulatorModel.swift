import SwiftUI
import GameController

/// libretro RETRO_DEVICE_ID_JOYPAD_* ids
enum Pad {
    static let b: UInt32 = 0, y: UInt32 = 1, select: UInt32 = 2, start: UInt32 = 3
    static let up: UInt32 = 4, down: UInt32 = 5, left: UInt32 = 6, right: UInt32 = 7
    static let a: UInt32 = 8, x: UInt32 = 9, l: UInt32 = 10, r: UInt32 = 11
}

final class EmulatorModel: ObservableObject {
    @Published var frame: UIImage?
    @Published var status = "No disk loaded"
    @Published var ctrlLatched = false
    @Published var controllerName: String?
    @Published var debugText = ""
    private var frameCount = 0
    private var host: LibretroHost?

    private var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    init() {
        boot()
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.attach(c) }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.controllerName = nil
        }
        GCController.controllers().forEach { attach($0) }
    }

    func boot() {
        let sys = docs.appendingPathComponent("system"), save = docs.appendingPathComponent("saves")
        for d in [sys, save] { try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        let h = LibretroHost(systemDirectory: sys.path, saveDirectory: save.path)
        h.onFrame = { [weak self] img in
            guard let self = self else { return }
            self.frame = img
            self.frameCount += 1
            if self.frameCount % 30 == 0 { self.debugText = self.host?.debugInfo() ?? "" }
        }
        host = h
        // Bundled sample disk (AppleWin's MASTER.DSK, DOS 3.3 master)
        if let url = Bundle.main.url(forResource: "MASTER", withExtension: "DSK") { load(url) }
    }

    func load(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // Copy into sandbox so the core can reopen it by path
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        if host?.loadDisk(atPath: dest.path) == true {
            status = dest.lastPathComponent; host?.start()
        } else { status = "Failed to load \(url.lastPathComponent)" }
    }

    // MARK: Keyboard

    /// Types one key: pressed now, released ~60 ms later (some games miss instant taps).
    /// `ch` is ASCII; `code` is a libretro RETROK_* value (0 = derive from `ch`).
    func key(_ ch: UInt32, code: UInt32 = 0) {
        var ch = ch, mods: UInt32 = 0
        var code = code
        if code == 0 {
            // Printable ASCII: libretro keycodes equal lowercase ASCII
            if ch >= 65 && ch <= 90 { code = ch + 32; mods |= 1 }      // uppercase -> Shift
            else if ch >= 32 && ch <= 126 { code = ch }
        }
        if ctrlLatched {
            if ch >= 0x40 && ch <= 0x7F {            // letters, @ [ \ ] ^ _
                if code == 0 { code = ch >= 97 ? ch : ch + 32 }
                ch &= 0x1F; mods |= 2
            }
            ctrlLatched = false
        }
        let (c, k, m) = (ch, code, mods)
        host?.sendKey(c, keycode: k, modifiers: m, down: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.host?.sendKey(c, keycode: k, modifiers: m, down: false)
        }
    }

    func reset() { host?.reset() }

    // MARK: Joystick / game controllers

    func pad(_ id: UInt32, _ pressed: Bool) { host?.setJoypadButton(id, pressed: pressed) }

    private func attach(_ c: GCController) {
        guard let g = c.extendedGamepad else { return }
        controllerName = c.vendorName ?? "Controller"
        let map: [(GCControllerButtonInput, UInt32)] = [
            (g.dpad.up, Pad.up), (g.dpad.down, Pad.down), (g.dpad.left, Pad.left), (g.dpad.right, Pad.right),
            (g.buttonA, Pad.a), (g.buttonB, Pad.b), (g.buttonX, Pad.x), (g.buttonY, Pad.y),
            (g.leftShoulder, Pad.l), (g.rightShoulder, Pad.r), (g.buttonMenu, Pad.start),
        ]
        for (button, id) in map {
            button.pressedChangedHandler = { [weak self] _, _, pressed in self?.pad(id, pressed) }
        }
        // Left stick also drives the D-pad
        g.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.pad(Pad.left, x < -0.5); self?.pad(Pad.right, x > 0.5)
            self?.pad(Pad.up, y > 0.5);    self?.pad(Pad.down, y < -0.5)
        }
    }
}
