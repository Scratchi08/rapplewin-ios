import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: EmulatorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    ForEach(CoreOptions.display) { picker($0) }
                    Toggle("Keep the 4:3 shape", isOn: $model.stretch43)
                    Toggle("Smooth scaling", isOn: $model.smoothScaling)
                    Toggle("Show the control bar", isOn: $model.showControlBar)
                }

                Section {
                    ForEach(CoreOptions.computer) { picker($0) }
                    Button("Restart the current disk now") { model.restartCurrentDisk(); dismiss() }
                } header: {
                    Text("Computer")
                } footer: {
                    Text(model.hardcore ? "Hardcore mode locks the computer type, cards and refresh rate."
                         : "Changing the computer type or its cards only takes effect when the disk is started again.")
                }

                Section("Keyboard") {
                    ForEach(CoreOptions.input) { picker($0) }
                    Text("With an iPad keyboard attached, typing works directly. Arrows, Esc, Tab and Ctrl+letter are mapped to the Apple II.")
                        .font(.footnote).foregroundColor(.secondary)
                }

                Section {
                    Button("Reset everything to defaults", role: .destructive) { model.resetOptions() }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func picker(_ opt: CoreOption) -> some View {
        Picker(opt.title, selection: Binding(
            get: { model.value(for: opt) },
            set: { model.setOption(opt, to: $0) })) {
            ForEach(opt.values, id: \.self) { Text($0).tag($0) }
        }
        .disabled(model.isLocked(opt))
    }
}
