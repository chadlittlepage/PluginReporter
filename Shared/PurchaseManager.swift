//
//  PurchaseManager.swift
//  PluginReporter (Shared)
//
//  Handles in-app purchases and unlock state across all platforms
//

import Foundation
import StoreKit

// MARK: - Product Identifiers

enum IAPProduct: String, CaseIterable {
    case unlockUnlimited = "com.chadlittlepage.PluginReporter.unlockUnlimited"

    var displayName: String {
        switch self {
        case .unlockUnlimited: 
            return "Unlock Unlimited Plugins"
        }
    }

    var description: String {
        switch self {
        case .unlockUnlimited: 
            return "Remove the 10-plugin limit and unlock all export features"
        }
    }
}

// MARK: - Purchase State

enum PurchaseState {
    case free          // Free tier (10 plugin limit)
    case unlocked      // Purchased unlimited
    case restoring     // Restoring purchases
    case purchasing    // Purchase in progress
}

// MARK: - Purchase Manager

@MainActor
class PurchaseManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var purchaseState: PurchaseState = .free
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published var showPurchaseError = false
    @Published var purchaseError: Error?

    // MARK: - Constants

    static let freePluginLimit = 10

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Shared Instance

    static let shared = PurchaseManager()

    // MARK: - Initialization

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Check for existing purchases on launch
        Task {
            await checkPurchaseState()
            await loadProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Check if user has unlimited access
    var isUnlocked: Bool {
        purchaseState == .unlocked
    }

    /// Check if a plugin count exceeds the free limit
    func exceedsFreeLimit(pluginCount: Int) -> Bool {
        !isUnlocked && pluginCount > Self.freePluginLimit
    }

    /// Get the limited plugin count for display
    func limitedPluginCount(_ totalCount: Int) -> Int {
        isUnlocked ? totalCount : min(totalCount, Self.freePluginLimit)
    }

    /// Load available products from App Store
    func loadProducts() async {
        isLoading = true

        do {
            let productIdentifiers = IAPProduct.allCases.map { $0.rawValue }
            let products = try await Product.products(for: productIdentifiers)

            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
                self.isLoading = false
            }

            AppLogger.info("Loaded \(products.count) IAP products")
        } catch {
            AppLogger.error("Failed to load products: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
                self.purchaseError = error
                self.showPurchaseError = true
            }
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async {
        await MainActor.run {
            self.purchaseState = .purchasing
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification): 
                let transaction = try checkVerified(verification)

                // Update purchase state
                await updatePurchaseState(for: transaction)

                // Finish the transaction
                await transaction.finish()

                AppLogger.info("Purchase successful: \(product.id)")

            case .userCancelled: 
                AppLogger.info("User cancelled purchase")
                await MainActor.run {
                    self.purchaseState = .free
                }

            case .pending: 
                AppLogger.info("Purchase pending approval")
                await MainActor.run {
                    self.purchaseState = .free
                }

            @unknown default: 
                AppLogger.warning("Unknown purchase result")
                await MainActor.run {
                    self.purchaseState = .free
                }
            }

        } catch {
            AppLogger.error("Purchase failed: \(error.localizedDescription)")
            await MainActor.run {
                self.purchaseState = .free
                self.purchaseError = error
                self.showPurchaseError = true
            }
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        await MainActor.run {
            self.purchaseState = .restoring
        }

        do {
            try await AppStore.sync()
            await checkPurchaseState()
            AppLogger.info("Purchases restored successfully")
        } catch {
            AppLogger.error("Failed to restore purchases: \(error.localizedDescription)")
            await MainActor.run {
                self.purchaseState = .free
                self.purchaseError = error
                self.showPurchaseError = true
            }
        }
    }

    // MARK: - Private Methods

    /// Check current purchase state from transaction history
    private func checkPurchaseState() async {
        var hasUnlockedPurchase = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productID == IAPProduct.unlockUnlimited.rawValue {
                    hasUnlockedPurchase = true
                    break
                }
            } catch {
                AppLogger.error("Transaction verification failed: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.purchaseState = hasUnlockedPurchase ? .unlocked : .free
        }

        AppLogger.info("Purchase state: \(hasUnlockedPurchase ? "unlocked" : "free")")
    }

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchaseState(for: transaction)
                    await transaction.finish()
                } catch {
                    AppLogger.error("Transaction update failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Update purchase state based on transaction
    private func updatePurchaseState(for transaction: Transaction) async {
        if transaction.productID == IAPProduct.unlockUnlimited.rawValue &&
           transaction.revocationDate == nil {
            await MainActor.run {
                self.purchaseState = .unlocked
            }
        }
    }

    /// Verify transaction is valid
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): 
            throw error
        case .verified(let safe): 
            return safe
        }
    }
}

// MARK: - UserDefaults Extension (Backup Storage)

extension PurchaseManager {

    /// Save unlock state to UserDefaults as backup (for development/testing)
    private func saveUnlockState(_ unlocked: Bool) {
        UserDefaults.standard.set(unlocked, forKey: "com.pluginreporter.isUnlocked")
    }

    /// Load unlock state from UserDefaults (for development/testing)
    private func loadUnlockState() -> Bool {
        UserDefaults.standard.bool(forKey: "com.pluginreporter.isUnlocked")
    }

    #if DEBUG
    /// DEBUG ONLY: Manually unlock for testing
    func debugUnlock() {
        purchaseState = .unlocked
        saveUnlockState(true)
        AppLogger.info("DEBUG: Manually unlocked")
    }

    /// DEBUG ONLY: Reset to free tier
    func debugReset() {
        purchaseState = .free
        saveUnlockState(false)
        AppLogger.info("DEBUG: Reset to free tier")
    }
    #endif
}