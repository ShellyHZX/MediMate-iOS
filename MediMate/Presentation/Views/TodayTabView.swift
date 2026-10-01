import SwiftUI

struct TodayTabView: View {
    @StateObject private var viewModel: TodayViewModel

    init(reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase) {
        _viewModel = StateObject(
            wrappedValue: TodayViewModel(reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase)
        )
    }

    var body: some View {
        NavigationStack {
            TodayView(viewModel: viewModel)
        }
    }
}
