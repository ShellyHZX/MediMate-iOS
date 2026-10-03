import Combine
import Foundation

@MainActor
final class MedicationManagementDependencies: ObservableObject {
    let reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase
    let recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase
    let recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase
    let skipScheduledDoseUseCase: SkipScheduledDoseUseCase
    let correctDoseRecordUseCase: CorrectDoseRecordUseCase
    let reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase
    let widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing
    let notificationScheduler: MedicationNotificationScheduling
    let reviewMedicationsUseCase: ReviewMedicationsUseCase
    let addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase
    let updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase
    let deactivateMedicationUseCase: DeactivateMedicationUseCase
    let deleteMedicationUseCase: DeleteMedicationUseCase

    init(
        reviewTodaysMedicationUseCase: ReviewTodaysMedicationUseCase,
        recordDoseAsTakenUseCase: RecordDoseAsTakenUseCase,
        recordMedicationMomentAsTakenUseCase: RecordMedicationMomentAsTakenUseCase,
        skipScheduledDoseUseCase: SkipScheduledDoseUseCase,
        correctDoseRecordUseCase: CorrectDoseRecordUseCase,
        reviewMedicationHistoryUseCase: ReviewMedicationHistoryUseCase,
        widgetSnapshotSynchronizer: WidgetSnapshotSynchronizing,
        notificationScheduler: MedicationNotificationScheduling,
        reviewMedicationsUseCase: ReviewMedicationsUseCase,
        addMedicationAndScheduleUseCase: AddMedicationAndScheduleUseCase,
        updateMedicationAndRescheduleUseCase: UpdateMedicationAndRescheduleUseCase,
        deactivateMedicationUseCase: DeactivateMedicationUseCase,
        deleteMedicationUseCase: DeleteMedicationUseCase
    ) {
        self.reviewTodaysMedicationUseCase = reviewTodaysMedicationUseCase
        self.recordDoseAsTakenUseCase = recordDoseAsTakenUseCase
        self.recordMedicationMomentAsTakenUseCase = recordMedicationMomentAsTakenUseCase
        self.skipScheduledDoseUseCase = skipScheduledDoseUseCase
        self.correctDoseRecordUseCase = correctDoseRecordUseCase
        self.reviewMedicationHistoryUseCase = reviewMedicationHistoryUseCase
        self.widgetSnapshotSynchronizer = widgetSnapshotSynchronizer
        self.notificationScheduler = notificationScheduler
        self.reviewMedicationsUseCase = reviewMedicationsUseCase
        self.addMedicationAndScheduleUseCase = addMedicationAndScheduleUseCase
        self.updateMedicationAndRescheduleUseCase = updateMedicationAndRescheduleUseCase
        self.deactivateMedicationUseCase = deactivateMedicationUseCase
        self.deleteMedicationUseCase = deleteMedicationUseCase
    }
}
