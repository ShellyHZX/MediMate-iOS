import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    let recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase
    let skipScheduledDoseUseCase: SkipScheduledDoseUseCase
    let reviewMedicationsUseCase: ReviewMedicationsUseCase
    let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    let updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase
    let deactivateMedicationUseCase: DeactivateMedicationUseCase

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.recordDoseAsTakenUseCase = recordDoseAsTakenUseCase
        self.skipScheduledDoseUseCase = skipScheduledDoseUseCase
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationAndRescheduleUseCase = updateMedicationAndRescheduleUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
    }
}
