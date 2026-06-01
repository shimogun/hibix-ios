import Testing
@testable import Hibix

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {

    private final class Spy {
        var saved: [WatchMode] = []
        var completed = false
        var notificationsRequested = false
    }

    private func makeViewModel(isPro: Bool, mode: OnboardingViewModel.Mode = .firstRun)
        -> (OnboardingViewModel, Spy) {
        let spy = Spy()
        let vm = OnboardingViewModel(
            mode: mode,
            isPro: { isPro },
            saveMode: { m in spy.saved.append(m) },
            requestNotifications: { spy.notificationsRequested = true },
            markComplete: { spy.completed = true }
        )
        return (vm, spy)
    }

    @Test
    func selectStart_solo_savesAndCompletes() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.solo)
        #expect(spy.saved == [.solo])
        #expect(spy.completed == true)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func selectStart_proModeWhenFree_showsPaywallWithoutSaving() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)
        #expect(vm.isPaywallPresented == true)
        #expect(vm.pendingProMode == .gentle)
        #expect(spy.saved.isEmpty)
        #expect(spy.completed == false)
    }

    @Test
    func selectStart_proModeWhenPro_savesDirectly() async {
        let (vm, spy) = makeViewModel(isPro: true)
        await vm.selectStartMode(.daily)
        #expect(spy.saved == [.daily])
        #expect(spy.completed == true)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func purchaseCompleted_savesPendingModeRequestsNotificationsAndCompletes() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)
        await vm.handlePurchaseCompleted()
        #expect(spy.saved == [.gentle])
        #expect(spy.notificationsRequested == true)
        #expect(spy.completed == true)
        #expect(vm.pendingProMode == nil)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func paywallDismissedWithoutPurchase_fallsBackToSolo() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)
        await vm.handlePaywallDismissedWithoutPurchase()
        #expect(spy.saved == [.solo])
        #expect(spy.completed == true)
        #expect(vm.pendingProMode == nil)
    }
}
