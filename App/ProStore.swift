import Foundation
import StoreKit
import WidgetKit

@Observable
final class ProStore {
    static let productID = "com.sunpebble.sleeptab.lifetime"
    static let proCacheKey = "isPro"

    var isPro: Bool
    var product: Product?
    var purchaseError: String?

    init() {
        // 买断解锁状态缓存在本地:已购用户冷启动即解锁,不依赖启动时那次
        // currentEntitlements 查询(TestFlight 更新后首启经常为空)。
        isPro = UserDefaults.standard.bool(forKey: Self.proCacheKey)
    }

    private func unlock() {
        isPro = true
        UserDefaults.standard.set(true, forKey: Self.proCacheKey)
        // 小组件是 Pro 功能:镜像解锁状态到 App Group 供 widget 读取
        UserDefaults(suiteName: WidgetSummary.appGroupID)?.set(true, forKey: Self.proCacheKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    var displayPrice: String { product?.displayPrice ?? "$1.99" }

    @MainActor
    func load() async {
        #if DEBUG
        if CommandLine.arguments.contains("-pro") {
            unlock()
            return
        }
        #endif
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                purchaseError = String(localized: "Product not available. Check App Store Connect setup.")
            }
        } catch {
            purchaseError = String(localized: "Couldn't load product: \(error.localizedDescription)")
        }
        await refresh()
    }

    @MainActor
    func refresh() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID {
                unlock()
            }
        }
    }

    @MainActor
    func purchase() async {
        purchaseError = nil
        guard let product else {
            purchaseError = String(localized: "Product not available. Check App Store Connect setup.")
            return
        }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                unlock()
                await transaction.finish()
            case .success(.unverified(_, let error)):
                purchaseError = String(localized: "Purchase couldn't be verified: \(error.localizedDescription)")
            case .pending:
                purchaseError = String(localized: "Purchase is pending approval.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = String(localized: "Purchase failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    func restore() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = String(localized: "Restore failed: \(error.localizedDescription)")
        }
        await refresh()
    }

    @MainActor
    func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update,
               transaction.productID == Self.productID {
                unlock()
                await transaction.finish()
            }
        }
    }
}
