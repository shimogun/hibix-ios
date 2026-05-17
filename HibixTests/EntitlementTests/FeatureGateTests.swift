import Testing
import Foundation
@testable import Hibix

@Suite("FeatureGate")
struct FeatureGateTests {

    @Test
    func allFeatures_blockedWhenFree() async {
        let provider = FakeEntitlementProvider(isPro: false)
        let gate = FeatureGate(provider: provider)
        let allFeatures: [Feature] = [.modeSwitch, .emergencyContact, .appLock, .reminders, .fullPixelHistory]
        for feature in allFeatures {
            let allowed = await gate.isAllowed(feature)
            #expect(!allowed, "Free should not allow \(feature)")
        }
    }

    @Test
    func allFeatures_grantedWhenPro() async {
        let provider = FakeEntitlementProvider(isPro: true)
        let gate = FeatureGate(provider: provider)
        let allFeatures: [Feature] = [.modeSwitch, .emergencyContact, .appLock, .reminders, .fullPixelHistory]
        for feature in allFeatures {
            let allowed = await gate.isAllowed(feature)
            #expect(allowed, "Pro should allow \(feature)")
        }
    }
}

final class FakeEntitlementProvider: EntitlementProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _isPro: Bool

    init(isPro: Bool) {
        self._isPro = isPro
    }

    var isPro: Bool {
        get async {
            lock.lock(); defer { lock.unlock() }
            return _isPro
        }
    }

    func setIsPro(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        _isPro = value
    }
}
