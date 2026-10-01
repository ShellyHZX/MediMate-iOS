import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewMedicationsUseCase: ReviewMedicationsUseCase
    let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    let updateMedicationUseCase: UpdateMedicationUseCase
    let deactivateMedicationUseCase: DeactivateMedicationUseCase

    init(
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationUseCase: UpdateMedicationUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase
    ) {
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationUseCase = updateMedicationUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
    }
}
