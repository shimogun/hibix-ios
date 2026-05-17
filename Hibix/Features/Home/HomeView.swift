import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isMoodPickerSheetPresented: Bool = false
    private let notificationTapCoordinator: NotificationTapCoordinator

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: HomeViewModel(
            repository: dependencies.moodEntryRepository,
            checkinService: dependencies.checkinService
        ))
        self.notificationTapCoordinator = dependencies.notificationTapCoordinator
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
            .navigationDestination(item: $bindable.selectedDetailDate) { dateString in
                EntryDetailView(date: dateString, viewModel: viewModel)
            }
            .task {
                await viewModel.load()
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
        }
    }

    private var moodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("今日の気分を選んでください")
                    .font(.title3)
                    .fontWeight(.semibold)
                MoodPickerView(selected: viewModel.todayEntry?.mood) { level in
                    Task {
                        await viewModel.recordMood(level)
                        isMoodPickerSheetPresented = false
                    }
                }
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
                          entries: viewModel.calendarEntries) { dateString in
            viewModel.selectedDetailDate = dateString
        }
    }

    private var picker: some View {
        MoodPickerView(selected: viewModel.todayEntry?.mood) { level in
            Task {
                await viewModel.recordMood(level)
            }
        }
    }
}
