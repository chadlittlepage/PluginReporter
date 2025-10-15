//
//  UpgradePromptView.swift
//  PluginReporter (Shared)
//
//  Upgrade prompt shown when free tier limit is reached
//

import SwiftUI
import StoreKit

struct UpgradePromptView: View {

    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Unlock Unlimited Plugins")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You've reached the free tier limit of \(PurchaseManager.freePluginLimit) plugins")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "infinity", text: "Scan unlimited plugins")
                FeatureRow(icon: "arrow.down.doc", text: "Export to CSV, PDF, and HTML")
                FeatureRow(icon: "icloud", text: "iCloud sync across all devices")
                FeatureRow(icon: "chart.bar", text: "Full dashboard analytics")
                FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Identify obsolete plugins")
            }
            .padding(.vertical, 24)

            // Purchase buttons
            VStack(spacing: 16) {
                if purchaseManager.isLoading {
                    ProgressView("Loading prices...")
                        .frame(height: 50)

                } else if let product = purchaseManager.availableProducts.first {
                    // Primary purchase button
                    Button {
                        Task {
                            await purchaseManager.purchase(product)
                            if purchaseManager.isUnlocked {
                                dismiss()
                            }
                        }
                    } {
                        HStack {
                            Text("Unlock for \(product.displayPrice)")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(purchaseManager.purchaseState == .purchasing)

                    // Restore purchases button
                    Button {
                        Task {
                            await purchaseManager.restorePurchases()
                            if purchaseManager.isUnlocked {
                                dismiss()
                            }
                        }
                    } {
                        Text("Restore Purchases")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                } else {
                    // Failed to load products
                    VStack(spacing: 12) {
                        Text("Unable to load pricing")
                            .foregroundColor(.secondary)

                        Button("Retry") {
                            Task {
                                await purchaseManager.loadProducts()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Continue with free button
                Button {
                    dismiss()
                } {
                    Text("Continue with Free (10 plugins)")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 500)
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 600)
        #endif
        .alert("Purchase Error", isPresented: $purchaseManager.showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = purchaseManager.purchaseError {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

// MARK: - Inline Upgrade Banner

struct UpgradeBanner: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showUpgradeSheet = false

    let pluginCount: Int

    var body: some View {
        if purchaseManager.exceedsFreeLimit(pluginCount: pluginCount) {
            Button {
                showUpgradeSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Free Tier Limit Reached")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Showing \(PurchaseManager.freePluginLimit) of \(pluginCount) plugins")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Text("Upgrade")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradePromptView()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UpgradePromptView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UpgradePromptView()
                .previewDisplayName("Upgrade Prompt")

            VStack {
                UpgradeBanner(pluginCount: 25)
                Spacer()
            }
            .previewDisplayName("Upgrade Banner")
        }
    }
}
#endif
