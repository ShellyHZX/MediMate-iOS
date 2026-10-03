import SwiftUI

struct ActivityTabView: View {
    @StateObject private var viewModel: HistoryViewModel

    init(
        reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        _viewModel = StateObject(
            wrappedValue: HistoryViewModel(
                reviewMedicationHistoryUseCase: reviewMedicationHistoryUseCase,
                correctDoseRecordUseCase: correctDoseRecordUseCase,
                calendar: calendar
            )
        )
    }

    var body: some View {
        NavigationStack {
            ActivityView(viewModel: viewModel)
        }
    }
}
