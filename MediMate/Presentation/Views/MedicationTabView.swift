import SwiftUI

struct MedicationTabView: View {
    @StateObject private var viewModel: MedicationListViewModel

    init(reviewMedicationsUseCase: ReviewMedicationsUseCase) {
        _viewModel = StateObject(
            wrappedValue: MedicationListViewModel(reviewMedicationsUseCase: reviewMedicationsUseCase)
        )
    }

    var body: some View {
        NavigationStack {
            MedicationListView(viewModel: viewModel)
        }
    }
}
