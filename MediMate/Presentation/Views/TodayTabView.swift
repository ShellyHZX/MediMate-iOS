import SwiftUI

struct TodayTabView: View {
    @StateObject private var viewModel: TodayViewModel

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase
    ) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            TodayView(viewModel: viewModel)
        }
    }
}
