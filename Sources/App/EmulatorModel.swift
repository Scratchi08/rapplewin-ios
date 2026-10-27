import SwiftUI
import GameController
import CryptoKit
import AVFoundation

/// libretro RETRO_DEVICE_ID_JOYPAD_* ids
enum Pad {
    static let b: UInt32 = 0, y: UInt32 = 1, select: UInt32 = 2, start: UInt32 = 3
    static let up: UInt32 = 4, down: UInt32 = 5, left: UInt32 = 6, right: UInt32 = 7
    static let a: UInt32 = 8, x: UInt32 = 9, l: UInt32 = 10, r: UInt32 = 11
}

struct RAToast: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let badge: URL?
    let unlock: Bool
}

/// A libretro core option the app exposes (keys and values from the AppleWin core's documentation).
struct CoreOption: Identifiable {
    let key: String
    let title: String
    let values: [String]
    let defaultValue: String
    var id: String { key }
}

enum CoreOptions {
    static let videoMode = CoreOption(key: "applewin_video_mode", title: "Screen colours",
        values: ["Color (RGB Card/Monitor)", "Color (Composite Idealized)", "Color (Composite Monitor)", "Color TV",
                 "B&W TV", "Monochrome (Amber)", "Monochrome (Green)", "Monochrome (White)"],
        defaultValue: "Color (RGB Card/Monitor)")
    static let videoStyle = CoreOption(key: "applewin_video_style", title: "Scanlines / resolution",
        values: ["Half Scanlines", "560 x 192", "280 x 192"], defaultValue: "Half Scanlines")
    static let refresh = CoreOption(key: "applewin_video_refresh_rate", title: "Refresh rate",
        values: ["60Hz", "50Hz"], defaultValue: "60Hz")
    static let machine = CoreOption(key: "applewin_machine", title: "Apple II type",
        values: ["Apple II (original)", "Apple II Plus", "Apple II J-Plus", "Apple //e (original)", "Apple //e (enhanced)",
                 "Pravets 82", "Pravets 8M", "Pravets 8A", "Base64A", "TK3000 //e"],
        defaultValue: "Apple //e (enhanced)")
    static let slot3 = CoreOption(key: "applewin_slot3", title: "Card in slot 3",
        values: ["Empty", "Video HD"], defaultValue: "Empty")
    static let slot4 = CoreOption(key: "applewin_slot4", title: "Card in slot 4",
        values: ["Empty", "Mockingboard C", "Mouse Card", "Phasor"], defaultValue: "Mockingboard C")
    static let slot5 = CoreOption(key: "applewin_slot5", title: "Card in slot 5",
        values: ["Empty", "Z80 SoftCard", "Mockingboard C", "Phasor", "SAM"], defaultValue: "Empty")
    static let slot7 = CoreOption(key: "applewin_slot7", title: "Card in slot 7",
        values: ["Empty", "Hard Disk Controller"], defaultValue: "Hard Disk Controller")
    static let keyboard = CoreOption(key: "applewin_keyboard_type", title: "Keyboard type",
        values: ["ASCII", "Original"], defaultValue: "ASCII")

    static let display = [videoMode, videoStyle, refresh]
    static let computer = [machine, slot3, slot4, slot5, slot7]
    static let input = [keyboard]
    static var all: [CoreOption] { display + computer + input }
    /// Settings that change how the emulated machine behaves; locked while hardcore mode is on.
    static let hardcoreLocked: Set<String> = [
        machine.key, slot3.key, slot4.key, slot5.key, slot7.key, refresh.key
    ]
}

struct DiskItem: Identifiable {
    let url: URL
    var id: String { url.lastPathComponent }
    var name: String { url.lastPathComponent }
}

final class EmulatorModel: ObservableObject {
    @Published var frame: UIImage?
    @Published var status = "No disk loaded"
    @Published var ctrlLatched = false
    @Published var controllerName: String?
    @Published var debugText = ""
    @Published var drive1: String?
    @Published var drive2: String?
    @Published var library: [DiskItem] = []
    @Published var message = ""
    @Published private(set) var bootName: String?

    // RetroAchievements
    let ra = RAClient()
    @Published var raUserName: String?
    @Published var raScore: UInt32 = 0
    @Published var raGameTitle: String?
    @Published var raSummary = ""
    @Published var raStatus = ""
    @Published var raError: String?
    @Published var raLog = ""
    @Published var raAchievements: [RAAchievement] = []
    @Published var toast: RAToast?
    @Published var hardcore: Bool = UserDefaults.standard.bool(forKey: "hardcore")
    private(set) var currentHash: String?
    private var unlockPlayer: AVAudioPlayer?

    // Settings (persisted)
    @Published var optionValues: [String: String] =
        UserDefaults.standard.dictionary(forKey: "coreOptions") as? [String: String] ?? [:]
    @Published var smoothScaling: Bool = UserDefaults.standard.bool(forKey: "smoothScaling") {
        didSet { UserDefaults.standard.set(smoothScaling, forKey: "smoothScaling") }
    }
    @Published var stretch43: Bool = (UserDefaults.standard.object(forKey: "stretch43") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(stretch43, forKey: "stretch43") }
    }
    @Published var showControlBar: Bool = (UserDefaults.standard.object(forKey: "showControlBar") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showControlBar, forKey: "showControlBar") }
    }
    private var frameCount = 0
    private var host: LibretroHost?

    static let diskExts: Set<String> = ["dsk", "do", "po", "nib", "woz", "2mg", "2img", "hdv", "zip", "gz", "m3u", "iie", "apl", "bin"]

    private var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    init() {
        ra.onToast = { [weak self] title, message, badge, unlock in
            self?.showToast(RAToast(title: title, message: message, badge: badge, unlock: unlock))
        }
        ra.onChange = { [weak self] in self?.refreshRA() }
        ra.onResetRequested = { [weak self] in self?.restartCurrentDisk() }
        ra.hardcore = hardcore
        boot()
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? GCController { self?.attach(c) }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.controllerName = nil
        }
        GCController.controllers().forEach { attach($0) }
        autoLoginRA()
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
        h.onTick = { [weak self] in self?.ra.doFrame() }
        host = h
        // Re-apply the options the user changed, before the first disk loads
        for (k, v) in optionValues { h.setOption(k, value: v) }
        // Resume the last booted disk, else the bundled sample (AppleWin's MASTER.DSK)
        if let last = UserDefaults.standard.string(forKey: "lastBoot"),
           FileManager.default.fileExists(atPath: docs.appendingPathComponent(last).path) {
            bootDisk(docs.appendingPathComponent(last))
        } else if let url = Bundle.main.url(forResource: "MASTER", withExtension: "DSK") {
            bootDisk(url)
        }
        refreshLibrary()
    }

    // MARK: Disks

    /// Copies a disk into the app's Documents folder (the library) unless it is already there.
    private func localCopy(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let dest = docs.appendingPathComponent(url.lastPathComponent)
        if url.standardizedFileURL.path == dest.standardizedFileURL.path { return dest }
        try? FileManager.default.removeItem(at: dest)
        do { try FileManager.default.copyItem(at: url, to: dest); storeHash(dest); return dest }
        catch { message = "Couldn't copy \(url.lastPathComponent): \(error.localizedDescription)"; return nil }
    }

    func refreshLibrary() {
        let items = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? []
        library = items
            .filter { Self.diskExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
            .map { DiskItem(url: $0) }
    }

    /// Loads a disk as the boot disk (starts it fresh).
    func bootDisk(_ url: URL) {
        guard let dest = localCopy(url) else { return }
        if host?.loadDisk(atPath: dest.path) == true {
            bootName = dest.lastPathComponent
            drive1 = bootName; drive2 = nil
            status = dest.lastPathComponent
            host?.start()
            UserDefaults.standard.set(bootName, forKey: "lastBoot")
            currentHash = hashFor(dest)
            ra.unloadGame()
            if ra.displayName != nil { loadRAGame() }
            message = "Booted \(dest.lastPathComponent)"
        } else {
            message = "Failed to load \(url.lastPathComponent)"
        }
        refreshLibrary()
    }

    /// Swaps a disk into drive 1 or 2 while the emulator keeps running.
    func insert(_ url: URL, drive: Int) {
        guard let dest = localCopy(url) else { return }
        guard host?.diskControlAvailable == true else {
            message = "This core build didn't expose disk control; use Boot instead."; return
        }
        if host?.insertDisk(atPath: dest.path, drive: Int32(drive)) == true {
            if drive == 2 { drive2 = dest.lastPathComponent } else { drive1 = dest.lastPathComponent }
            message = "Inserted \(dest.lastPathComponent) in Drive \(drive)"
        } else {
            message = "The core rejected \(dest.lastPathComponent) for Drive \(drive)"
        }
        refreshLibrary()
    }

    func eject(drive: Int) {
        if host?.ejectDriveNumber(Int32(drive)) == true {
            if drive == 2 { drive2 = nil } else { drive1 = nil }
            message = "Ejected Drive \(drive)"
        } else {
            message = "Couldn't eject Drive \(drive)"
        }
    }

    func delete(_ item: DiskItem) {
        try? FileManager.default.removeItem(at: item.url)
        message = "Deleted \(item.name)"
        refreshLibrary()
    }

    // MARK: Save states (per boot disk, 3 slots)

    private func stateURL(slot: Int) -> URL {
        docs.appendingPathComponent("saves/\(bootName ?? "none").slot\(slot).state")
    }
    func hasState(slot: Int) -> Bool { FileManager.default.fileExists(atPath: stateURL(slot: slot).path) }

    private func raProgressURL(slot: Int) -> URL { stateURL(slot: slot).appendingPathExtension("ra") }

    func saveState(slot: Int) {
        guard !hardcore else { message = "Save states are turned off in hardcore mode"; return }
        if host?.saveState(toPath: stateURL(slot: slot).path) == true {
            // Keep achievement progress in step with the emulator state
            if let progress = ra.serializeProgress() { try? progress.write(to: raProgressURL(slot: slot)) }
            message = "Saved slot \(slot)"
        } else {
            message = "The core couldn't save a state"
        }
    }
    func loadState(slot: Int) {
        guard !hardcore else { message = "Save states are turned off in hardcore mode"; return }
        if host?.loadState(fromPath: stateURL(slot: slot).path) == true {
            if let d = try? Data(contentsOf: raProgressURL(slot: slot)), ra.deserializeProgress(d) {
                // restored
            } else {
                ra.reset()
            }
            message = "Loaded slot \(slot)"
        } else {
            message = "The core couldn't load slot \(slot)"
        }
    }

    // MARK: Settings

    func value(for opt: CoreOption) -> String { optionValues[opt.key] ?? opt.defaultValue }

    func isLocked(_ opt: CoreOption) -> Bool { hardcore && CoreOptions.hardcoreLocked.contains(opt.key) }

    func setOption(_ opt: CoreOption, to value: String) {
        guard !isLocked(opt) else { return }
        optionValues[opt.key] = value
        UserDefaults.standard.set(optionValues, forKey: "coreOptions")
        host?.setOption(opt.key, value: value)
    }

    func resetOptions() {
        for opt in CoreOptions.all where !isLocked(opt) {
            optionValues[opt.key] = nil
            host?.setOption(opt.key, value: opt.defaultValue)
        }
        UserDefaults.standard.set(optionValues, forKey: "coreOptions")
    }

    /// Hardware changes (machine type, cards) need the current disk to be started again.
    func restartCurrentDisk() {
        if let name = bootName { bootDisk(docs.appendingPathComponent(name)) }
    }

    // MARK: RetroAchievements

    /// Hardcore: no save states, no hardware changes. Switching it on with a game running restarts the game.
    func setHardcore(_ on: Bool) {
        hardcore = on
        UserDefaults.standard.set(on, forKey: "hardcore")
        ra.hardcore = on
        message = on ? "Hardcore mode on" : "Hardcore mode off"
        refreshRA()
    }

    /// RetroAchievements identifies Apple II games by the MD5 of the whole disk image. AppleWin writes to
    /// images, which changes the MD5, so the hash of the pristine file is stored when it is imported.
    private func md5(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func storeHash(_ url: URL) {
        guard let h = md5(of: url) else { return }
        var d = UserDefaults.standard.dictionary(forKey: "diskHashes") as? [String: String] ?? [:]
        d[url.lastPathComponent] = h
        UserDefaults.standard.set(d, forKey: "diskHashes")
    }
    private func hashFor(_ url: URL) -> String? {
        let d = UserDefaults.standard.dictionary(forKey: "diskHashes") as? [String: String] ?? [:]
        if let h = d[url.lastPathComponent] { return h }
        storeHash(url)
        return (UserDefaults.standard.dictionary(forKey: "diskHashes") as? [String: String])?[url.lastPathComponent]
    }

    private func autoLoginRA() {
        guard let user = UserDefaults.standard.string(forKey: "raUser"),
              let token = Keychain.get("raToken"), !token.isEmpty else { return }
        raStatus = "Signing in…"
        ra.login(withUsername: user, token: token) { [weak self] err, _, _ in
            guard let self = self else { return }
            if let err = err { self.raError = err; self.raStatus = "" }
            else { self.loadRAGame() }
            self.refreshRA()
        }
    }

    func raLogin(user: String, password: String) {
        raError = nil
        raStatus = "Signing in…"
        ra.login(withUsername: user, password: password) { [weak self] err, name, token in
            guard let self = self else { return }
            if let err = err { self.raError = err; self.raStatus = ""; return }
            UserDefaults.standard.set(name ?? user, forKey: "raUser")
            Keychain.set(token ?? "", for: "raToken")
            self.loadRAGame()
            self.refreshRA()
        }
    }

    func raLogout() {
        ra.unloadGame()
        ra.logout()
        UserDefaults.standard.removeObject(forKey: "raUser")
        Keychain.delete("raToken")
        raStatus = ""
        refreshRA()
    }

    func loadRAGame() {
        guard let hash = currentHash else { return }
        raStatus = "Identifying game…"
        ra.loadGame(withHash: hash) { [weak self] err in
            guard let self = self else { return }
            self.raStatus = err ?? ""
            self.raError = nil
            if err != nil { self.raGameTitle = nil }
            self.refreshRA()
        }
    }

    func refreshRA() {
        raUserName = ra.displayName
        raScore = ra.score
        raGameTitle = ra.gameTitle
        raSummary = ra.gameLoaded
            ? "Unlocked \(ra.unlockedCount) of \(ra.coreCount) achievements · \(ra.pointsUnlocked)/\(ra.pointsTotal) points"
            : ""
        raAchievements = ra.gameLoaded ? ra.achievements() : []
        raLog = ra.logText
    }

    private func showToast(_ t: RAToast) {
        toast = t
        if t.unlock, let url = Bundle.main.url(forResource: "unlock", withExtension: "wav") {
            unlockPlayer = try? AVAudioPlayer(contentsOf: url)
            unlockPlayer?.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.toast?.id == t.id { self?.toast = nil }
        }
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

    func reset() { host?.reset(); ra.reset() }

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
