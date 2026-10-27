import SwiftUI

struct EmulatorScreen: View {
    @ObservedObject var model: EmulatorModel
    @State private var showDisks = false
    @State private var showAchievements = false
    @State private var showSettings = false
    @State private var showJoystick = false
    @State private var softKeyboard = false

    private var sheetOpen: Bool { showDisks || showAchievements || showSettings }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let f = model.frame {
                    Image(uiImage: f)
                        .interpolation(model.smoothScaling ? .high : .none)
                        .resizable()
                        .aspectRatio(model.stretch43 ? CGFloat(4.0 / 3.0) : f.size.width / max(f.size.height, 1),
                                     contentMode: .fit)
                } else {
                    Text(model.status).foregroundColor(.gray)
                }

                // Invisible: receives the on-screen and hardware keyboards
                KeyCapture(model: model, active: !sheetOpen, softKeyboard: softKeyboard && !showJoystick)
                    .frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false)

                if showJoystick { joystickOverlay }
                if let name = model.controllerName {
                    VStack { Text("🎮 \(name)").font(.caption).padding(4)
                        .background(Color.black.opacity(0.5)).cornerRadius(6); Spacer() }
                        .frame(maxWidth: .infinity, alignment: .trailing).padding(6)
                }
                if !model.showControlBar {
                    VStack { HStack { Button("⚙︎") { showSettings = true }
                        .buttonStyle(.bordered).opacity(0.6); Spacer() }; Spacer() }.padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !showJoystick { softKeyboard.toggle() } }
            .overlay(alignment: .top) {
                if let t = model.toast {
                    ToastView(toast: t).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: model.toast?.id)

            if model.showControlBar { controlBar }
        }
        .sheet(isPresented: $showDisks) { DiskManagerView(model: model) }
        .sheet(isPresented: $showAchievements) { AchievementsView(model: model) }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    }

    // Apple II arrows are ^H ^U ^K ^J; libretro keycodes: Left 276, Right 275, Up 273, Down 274
    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                if model.hardcore {
                    Text("HC").font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red).clipShape(Capsule())
                }
                Button("Ctrl") { model.ctrlLatched.toggle() }
                    .tint(model.ctrlLatched ? .orange : nil)
                    .buttonStyle(.borderedProminent)
                key("Esc", 27, 27); key("Tab", 9, 9); key("↵", 13, 13)
                key("←", 8, 276); key("→", 21, 275); key("↑", 11, 273); key("↓", 10, 274)
                Divider().frame(height: 24)
                Button(softKeyboard ? "⌨ ✓" : "⌨") { softKeyboard.toggle(); if softKeyboard { showJoystick = false } }
                Button(showJoystick ? "Joy ✓" : "Joy") { showJoystick.toggle(); softKeyboard = false }
                Button("Reset") { model.reset() }
                Button("Disks") { showDisks = true }
                Button("🏆") { showAchievements = true }
                Button("⚙︎") { showSettings = true }
            }
            .buttonStyle(.bordered).padding(8)
        }
    }

    private func key(_ label: String, _ ch: UInt32, _ code: UInt32) -> some View {
        Button(label) { model.key(ch, code: code) }
    }

    private var joystickOverlay: some View {
        VStack {
            Text(model.debugText).font(.system(size: 9, design: .monospaced)).foregroundColor(.yellow)
                .padding(4).background(Color.black.opacity(0.6)).cornerRadius(4)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6)
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
