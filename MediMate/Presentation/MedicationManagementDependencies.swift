import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    let reviewMedicationsUseCase: ReviewMedicationsUseCase
    let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    let updateMedicationUseCase: UpdateMedicationUseCase
    let deactivateMedicationUseCase: DeactivateMedicationUseCase

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationUseCase: UpdateMedicationUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationUseCase = updateMedicationUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
    }
}
