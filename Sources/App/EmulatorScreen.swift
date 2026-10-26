import SwiftUI

struct EmulatorScreen: View {
    @ObservedObject var model: EmulatorModel
    @State private var pickingDisk = false
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
            }
            .onTapGesture { kbFocus = true }

            // Hidden field captures the iOS software keyboard
            TextField("", text: $typed).focused($kbFocus).frame(width: 1, height: 1).opacity(0.01)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .onChange(of: typed) { new in
                    for u in new.unicodeScalars { model.key(u.value) }
                    typed = ""
                }

            // Apple II key codes: arrows are ^H ^U ^K ^J
            HStack {
                keyBtn("Esc", 27); keyBtn("↵", 13); keyBtn("←", 8); keyBtn("→", 21)
                keyBtn("↑", 11); keyBtn("↓", 10)
                Button("^C") { model.key(3) }
                Spacer()
                Button("Reset") { model.reset() }
                Button("Disk…") { pickingDisk = true }
            }
            .buttonStyle(.bordered).padding(8)
        }
        .fileImporter(isPresented: $pickingDisk, allowedContentTypes: [.data]) { r in
            if case .success(let url) = r { model.load(url) }
        }
    }

    private func keyBtn(_ label: String, _ code: UInt32) -> some View {
        Button(label) { model.key(code) }
    }
}
