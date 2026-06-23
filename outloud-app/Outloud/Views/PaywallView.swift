import SwiftUI
import StoreKit
import ReaderCore

/// The paywall. Primary CTA is **lifetime** ("Pay once. No subscription,
/// ever."); the monthly subscription is shown only as a crossed-out anchor.
/// The pitch is on-device/offline + length unlock — never voice quality.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false

    private var lifetime: Product? { store.product(id: ProductID.lifetime) }
    private var monthly: Product? { store.product(id: ProductID.monthly) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    valueProps
                    lifetimeCard
                    if let monthly { anchorRow(monthly) }
                    Button("Restore Purchases") {
                        Task { await store.restore(); if store.isUnlocked { dismiss() } }
                    }
                    .font(.footnote)

                    legal
                }
                .padding()
            }
            .navigationTitle("Unlock the full document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: store.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 44)).foregroundStyle(.tint)
            Text("Hear the whole thing")
                .font(.title2.bold())
            Text("You've reached the free preview. Unlock unlimited length — everything stays 100% on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var valueProps: some View {
        VStack(alignment: .leading, spacing: 12) {
            prop("checkmark.icloud", "100% on-device", "Nothing is ever uploaded. Works in airplane mode.")
            prop("infinity", "Unlimited length", "No 5-minute cap — finish any document.")
            prop("person.wave.2.fill", "Every voice + speed", "The full voice shelf and all speeds.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prop(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var lifetimeCard: some View {
        VStack(spacing: 10) {
            Text("Pay once. No subscription, ever.")
                .font(.headline)
            if let lifetime {
                Button {
                    purchasing = true
                    Task { await store.purchase(lifetime); purchasing = false }
                } label: {
                    HStack {
                        Text("Unlock for life")
                        Spacer()
                        Text(lifetime.displayPrice).bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchasing)
            } else {
                ProgressView()
            }
        }
        .padding()
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.tint, lineWidth: 1.5))
    }

    private func anchorRow(_ monthly: Product) -> some View {
        // Anchor: shown crossed-out so lifetime reads as the obvious deal.
        HStack {
            Text("Monthly")
            Spacer()
            Text(monthly.displayPrice + "/mo")
                .strikethrough()
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.horizontal)
    }

    private var legal: some View {
        VStack(spacing: 4) {
            if let err = store.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
            Text("Purchases are processed by Apple. Lifetime is a one-time purchase.")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
