import SwiftUI

struct TodayTabView: View {
    @StateObject private var viewModel: TodayViewModel

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                recordMedicationMomentAsTakenUseCase: recordMedicationMomentAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase,
                correctDoseRecordUseCase: correctDoseRecordUseCase,
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
