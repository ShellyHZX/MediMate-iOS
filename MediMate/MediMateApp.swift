import SwiftUI

@main
struct MediMateApp: App {
    private let persistenceController: PersistenceController
    @StateObject private var medicationManagementDependencies: MedicationManagementDependencies

    init() {
        let persistenceController = PersistenceController.shared
        let medicationRepository = CoreDataMedicationRepository(context: persistenceController.viewContext)
        let scheduledDoseRepository = CoreDataScheduledDoseRepository(context: persistenceController.viewContext)
        let calendar = Calendar.autoupdatingCurrent
        let reviewTodaysMedicationUseCase = ReviewTodaysMedicationUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )
        let recordDoseAsTakenUseCase = RecordDoseAsTakenUseCase(
            scheduledDoseRepository: scheduledDoseRepository
        )
        let skipScheduledDoseUseCase = SkipScheduledDoseUseCase(
            scheduledDoseRepository: scheduledDoseRepository
        )
        let reviewMedicationsUseCase = ReviewMedicationsUseCase(medicationRepository: medicationRepository)
        let addMedicationUseCase = AddMedicationUseCase(medicationRepository: medicationRepository)
        let scheduleMedicationUseCase = ScheduleMedicationUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )
        let addMedicationAndScheduleUseCase = AddMedicationAndScheduleUseCase(
            addMedicationUseCase: addMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            calendar: calendar
        )
        let updateMedicationUseCase = UpdateMedicationUseCase(medicationRepository: medicationRepository)
        let updateMedicationAndRescheduleUseCase = UpdateMedicationAndRescheduleUseCase(
            updateMedicationUseCase: updateMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )
        let deactivateMedicationUseCase = DeactivateMedicationUseCase(medicationRepository: medicationRepository)

        self.persistenceController = persistenceController
        _medicationManagementDependencies = StateObject(
            wrappedValue: MedicationManagementDependencies(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase,
                reviewMedicationsUseCase: reviewMedicationsUseCase,
                addMedicationAndScheduleUseCase: addMedicationAndScheduleUseCase,
                updateMedicationAndRescheduleUseCase: updateMedicationAndRescheduleUseCase,
                deactivateMedicationUseCase: deactivateMedicationUseCase
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicationManagementDependencies)
        }
    }
}
