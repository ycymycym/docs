import SwiftUI
import ReaderCore

/// Voice picker. Free shelf is always selectable; the rest are gated behind the
/// paid entitlement. Remember: voices are packaging, not the value prop —
/// the gate here is a soft upsell, never a quality wall on the free voices.
struct VoicePickerView: View {
    @EnvironmentObject private var playback: PlaybackEngine
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Free voices") {
                    ForEach(VoiceCatalog.freeShelf) { voice in
                        row(voice, locked: false)
                    }
                }
                Section {
                    ForEach(VoiceCatalog.all.filter { !$0.isFreeTier }) { voice in
                        row(voice, locked: !store.isUnlocked)
                    }
                } header: {
                    Text("All voices")
                } footer: {
                    if !store.isUnlocked {
                        Text("Unlock the full document to use every voice and speed control.")
                    }
                }
            }
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func row(_ voice: Voice, locked: Bool) -> some View {
        Button {
            if locked { showPaywall = true }
            else { playback.setVoice(voice); dismiss() }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.displayName)
                    Text(voice.language.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                } else if voice.id == playback.voice.id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .tint(.primary)
    }
}
