import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewMedicationsUseCase: ReviewMedicationsUseCase
    let addMedicationUseCase: AddMedicationUseCase
    let updateMedicationUseCase: UpdateMedicationUseCase
    let deactivateMedicationUseCase: DeactivateMedicationUseCase

    init(
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        addMedicationUseCase: AddMedicationUseCase,
        updateMedicationUseCase: UpdateMedicationUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase
    ) {
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.addMedicationUseCase = addMedicationUseCase
        self.updateMedicationUseCase = updateMedicationUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
    }
}
