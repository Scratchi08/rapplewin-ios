import SwiftUI

struct EmulatorScreen: View {
    @ObservedObject var model: EmulatorModel
    @State private var pickingDisk = false
    @State private var showJoystick = false
    @State private var typed = ""
    @FocusState private var kbFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let f = model.frame {
                    Image(uiImage: f).interpolation(.none).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Text(model.status).foregroundColor(.gray)
                }
                if showJoystick { joystickOverlay }
                if let name = model.controllerName {
                    VStack { Text("🎮 \(name)").font(.caption).padding(4)
                        .background(Color.black.opacity(0.5)).cornerRadius(6); Spacer() }
                        .frame(maxWidth: .infinity, alignment: .trailing).padding(6)
                }
            }
            .onTapGesture { if !showJoystick { kbFocus = true } }

            // Hidden field captures the iOS software keyboard
            TextField("", text: $typed).focused($kbFocus).frame(width: 1, height: 1).opacity(0.01)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .onChange(of: typed) { new in
                    for u in new.unicodeScalars { model.key(u.value) }
                    typed = ""
                }

            controlBar
        }
        .fileImporter(isPresented: $pickingDisk, allowedContentTypes: [.data]) { r in
            if case .success(let url) = r { model.load(url) }
        }
    }

    // Apple II arrows are ^H ^U ^K ^J; libretro keycodes: Left 276, Right 275, Up 273, Down 274
    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button("Ctrl") { model.ctrlLatched.toggle() }
                    .tint(model.ctrlLatched ? .orange : nil)
                    .buttonStyle(.borderedProminent)
                key("Esc", 27, 27); key("Tab", 9, 9); key("↵", 13, 13)
                key("←", 8, 276); key("→", 21, 275); key("↑", 11, 273); key("↓", 10, 274)
                Divider().frame(height: 24)
                Button(showJoystick ? "Joy ✓" : "Joy") { showJoystick.toggle(); kbFocus = false }
                Button("Reset") { model.reset() }
                Button("Disk…") { pickingDisk = true }
            }
            .buttonStyle(.bordered).padding(8)
        }
    }

    private func key(_ label: String, _ ch: UInt32, _ code: UInt32) -> some View {
        Button(label) { model.key(ch, code: code) }
    }

    private var joystickOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(spacing: 4) {
                    PadButton(label: "▲") { model.pad(Pad.up, $0) }
                    HStack(spacing: 48) {
                        PadButton(label: "◀") { model.pad(Pad.left, $0) }
                        PadButton(label: "▶") { model.pad(Pad.right, $0) }
                    }
                    PadButton(label: "▼") { model.pad(Pad.down, $0) }
                }
                Spacer()
                HStack(spacing: 16) {
                    PadButton(label: "B") { model.pad(Pad.b, $0) }
                    PadButton(label: "A") { model.pad(Pad.a, $0) }
                }.padding(.bottom, 24)
            }
            .padding(16)
        }
    }
}

/// Round on-screen button that reports press/release.
struct PadButton: View {
    let label: String
    let onChange: (Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Text(label).font(.title2.bold()).foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.white.opacity(pressed ? 0.45 : 0.18))
            .clipShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true; onChange(true) } }
                .onEnded { _ in pressed = false; onChange(false) })
    }
}
