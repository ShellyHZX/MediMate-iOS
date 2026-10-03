import SwiftUI

struct TodayTabView: View {
    @StateObject private var viewModel: TodayViewModel

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                recordMedicationMomentAsTakenUseCase: recordMedicationMomentAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase,
                correctDoseRecordUseCase: correctDoseRecordUseCase,
                widgetSnapshotSynchronizer: widgetSnapshotSynchronizer,
                calendar: calendar
            )
        )
    }

    var body: some View {
        NavigationStack {
            TodayView(viewModel: viewModel)
        }
    }
}
