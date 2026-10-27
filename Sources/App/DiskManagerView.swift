import SwiftUI
import UniformTypeIdentifiers

struct DiskManagerView: View {
    @ObservedObject var model: EmulatorModel
    @Environment(\.dismiss) private var dismiss

    private enum PickMode { case boot, drive1, drive2 }
    @State private var pickMode: PickMode = .boot
    @State private var picking = false

    var body: some View {
        NavigationStack {
            List {
                Section("Drives") {
                    driveRow(1, model.drive1)
                    driveRow(2, model.drive2)
                }

                Section("Add a disk from Files") {
                    Button("Boot a new disk…") { pick(.boot) }
                    Button("Insert in Drive 1…") { pick(.drive1) }
                    Button("Insert in Drive 2…") { pick(.drive2) }
                }

                Section("Library (tap a disk for options)") {
                    if model.library.isEmpty { Text("No disks yet").foregroundColor(.secondary) }
                    ForEach(model.library) { item in
                        Menu {
                            Button("Boot") { model.bootDisk(item.url) }
                            Button("Insert in Drive 1") { model.insert(item.url, drive: 1) }
                            Button("Insert in Drive 2") { model.insert(item.url, drive: 2) }
                            Button("Delete", role: .destructive) { model.delete(item) }
                        } label: {
                            Text(item.name).lineLimit(1)
                        }
                    }
                }

                Section("Save states: \(model.bootName ?? "no disk")") {
                    if model.hardcore {
                        Text("Save states are turned off in hardcore mode.").font(.footnote).foregroundColor(.secondary)
                    }
                    ForEach(1...3, id: \.self) { slot in
                        HStack {
                            Text("Slot \(slot)")
                            Spacer()
                            Button("Save") { model.saveState(slot: slot) }.buttonStyle(.bordered).disabled(model.hardcore)
                            Button("Load") { model.loadState(slot: slot) }.buttonStyle(.bordered)
                                .disabled(model.hardcore || !model.hasState(slot: slot))
                        }
                    }
                }

                if !model.message.isEmpty {
                    Section { Text(model.message).font(.footnote) }
                }
            }
            .navigationTitle("Disks")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.data]) { result in
                guard case .success(let url) = result else { return }
                switch pickMode {
                case .boot:   model.bootDisk(url)
                case .drive1: model.insert(url, drive: 1)
                case .drive2: model.insert(url, drive: 2)
                }
            }
        }
    }

    private func pick(_ mode: PickMode) { pickMode = mode; picking = true }

    private func driveRow(_ n: Int, _ name: String?) -> some View {
        HStack {
            Text("Drive \(n)").bold()
            Spacer()
            Text(name ?? "empty").foregroundColor(.secondary).lineLimit(1)
            if name != nil { Button("Eject") { model.eject(drive: n) }.buttonStyle(.bordered) }
        }
    }
}
