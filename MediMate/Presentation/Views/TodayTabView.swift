import SwiftUI

struct TodayTabView: View {
    @StateObject private var viewModel: TodayViewModel

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase
    ) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase,
                correctDoseRecordUseCase: correctDoseRecordUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            TodayView(viewModel: viewModel)
        }
    }
}
