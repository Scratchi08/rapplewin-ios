import SwiftUI

final class EmulatorModel: ObservableObject {
    @Published var frame: UIImage?
    @Published var status = "No disk loaded"
    private var host: LibretroHost?

    private var docs: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    init() { boot() }

    func boot() {
        let sys = docs.appendingPathComponent("system"), save = docs.appendingPathComponent("saves")
        for d in [sys, save] { try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        let h = LibretroHost(systemDirectory: sys.path, saveDirectory: save.path)
        h.onFrame = { [weak self] img in self?.frame = img }
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

    func key(_ ch: UInt32, code: UInt32 = 0) {
        host?.sendKey(ch, keycode: code, down: true)
        host?.sendKey(ch, keycode: code, down: false)
    }
    func reset() { host?.reset() }
}
