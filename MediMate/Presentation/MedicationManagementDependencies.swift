import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewMedicationsUseCase: ReviewMedicationsUseCase

    init(reviewMedicationsUseCase: ReviewMedicationsUseCase) {
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
    }
}
