import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isMoodPickerSheetPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @Bindable private var entitlement: EntitlementManager
    private let dependencies: AppDependencies
    private let notificationTapCoordinator: NotificationTapCoordinator
    private let makePaywallViewModel: () -> PaywallViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: HomeViewModel(
            repository: dependencies.moodEntryRepository,
            checkinService: dependencies.checkinService
        ))
        self.dependencies = dependencies
        self.entitlement = dependencies.entitlementManager
        self.notificationTapCoordinator = dependencies.notificationTapCoordinator
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
    }

    var body: some View {
        @Bindable var bindable = viewModel
        NavigationStack {
            VStack(spacing: 24) {
                header
                Spacer(minLength: 0)
                calendar
                Spacer(minLength: 0)
                picker
                if let lastErrorMessage = viewModel.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .navigationDestination(item: $bindable.selectedDetailDate) { dateString in
                EntryDetailView(date: dateString, viewModel: viewModel)
            }
            .task(id: entitlement.isPro) {
                await viewModel.load(isPro: entitlement.isPro)
            }
            .onChange(of: notificationTapCoordinator.lastTapId) { _, newId in
                guard newId != nil else { return }
                if viewModel.todayEntry == nil {
                    isMoodPickerSheetPresented = true
                }
            }
            .sheet(isPresented: $isMoodPickerSheetPresented) {
                moodPickerSheet
            }
            .sheet(isPresented: $bindable.isMemoSheetPresented) {
                MoodMemoView(
                    initialMemo: viewModel.todayEntry?.memo,
                    mood: viewModel.todayEntry?.mood,
                    onSave: { text in
                        await viewModel.saveMemo(text)
                    },
                    onSkip: {
                        viewModel.dismissMemoSheet()
                    }
                )
            }
            .sheet(isPresented: $bindable.isPaywallPresented) {
                PaywallView(
                    viewModel: makePaywallViewModel(),
                    onPurchaseCompleted: {
                        viewModel.isPaywallPresented = false
                    },
                    onDismiss: {
                        viewModel.isPaywallPresented = false
                    }
                )
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(dependencies: dependencies) {
                    isSettingsPresented = false
                }
            }
            .overlay(alignment: .center) {
                ZStack {
                    if let mood = viewModel.lastSavedMood {
                        flyingReplica(for: mood)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .animation(.spring(duration: 0.6), value: viewModel.lastSavedMood)
            }
            .overlay(alignment: .bottom) {
                ZStack {
                    if let message = viewModel.toastMessage {
                        Text(message)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.bottom, 80)
                            .transition(.opacity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(message)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
            }
        }
    }

    private func flyingReplica(for mood: MoodLevel) -> some View {
        Image(mood.iconAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .shadow(color: .black.opacity(0.2), radius: 12)
    }

    private var moodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("今日の気分を選んでください")
                    .font(.title3)
                    .fontWeight(.semibold)
                MoodPickerView(
                    selected: viewModel.todayEntry?.mood,
                    onSelect: { level in
                        Task {
                            await viewModel.recordMood(level)
                            isMoodPickerSheetPresented = false
                        }
                    },
                    onLongPress: { level in
                        Task {
                            await viewModel.recordMoodWithoutMemo(level)
                            isMoodPickerSheetPresented = false
                        }
                    }
                )
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        isMoodPickerSheetPresented = false
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(HibixDate.todayString())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let mood = viewModel.todayEntry?.mood {
                Text("今日: \(mood.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
            } else {
                Text("今日の気分を記録")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var calendar: some View {
        PixelCalendarView(today: Date(),
                          entries: viewModel.calendarEntries,
                          isPro: entitlement.isPro,
                          earliestEntryDate: viewModel.earliestEntryDate,
                          onSelectDate: { dateString in
                              viewModel.selectedDetailDate = dateString
                          },
                          onUpgradeRequest: {
                              viewModel.presentPaywall()
                          })
    }

    private var picker: some View {
        MoodPickerView(
            selected: viewModel.todayEntry?.mood,
            onSelect: { level in
                Task {
                    await viewModel.recordMood(level)
                }
            },
            onLongPress: { level in
                Task {
                    await viewModel.recordMoodWithoutMemo(level)
                }
            }
        )
    }
}
