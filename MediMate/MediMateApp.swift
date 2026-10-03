import SwiftUI

@main
struct MediMateApp: App {
    @Environment(\.scenePhase) private var scenePhase

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
        let recordMedicationMomentAsTakenUseCase = RecordMedicationMomentAsTakenUseCase(
            scheduledDoseRepository: scheduledDoseRepository
        )
        let skipScheduledDoseUseCase = SkipScheduledDoseUseCase(
            scheduledDoseRepository: scheduledDoseRepository
        )
        let correctDoseRecordUseCase = CorrectDoseRecordUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )
        let reviewMedicationHistoryUseCase = ReviewMedicationHistoryUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )
        let widgetSnapshotSynchronizer = WidgetSnapshotSynchronizer(
            reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
            snapshotStore: MedicationWidgetSnapshotStore(),
            calendar: calendar
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
        let deleteMedicationUseCase = DeleteMedicationUseCase(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository
        )

        self.persistenceController = persistenceController
        _medicationManagementDependencies = StateObject(
            wrappedValue: MedicationManagementDependencies(
                reviewTodaysMedicationUseCase: reviewTodaysMedicationUseCase,
                recordDoseAsTakenUseCase: recordDoseAsTakenUseCase,
                recordMedicationMomentAsTakenUseCase: recordMedicationMomentAsTakenUseCase,
                skipScheduledDoseUseCase: skipScheduledDoseUseCase,
                correctDoseRecordUseCase: correctDoseRecordUseCase,
                reviewMedicationHistoryUseCase: reviewMedicationHistoryUseCase,
                widgetSnapshotSynchronizer: widgetSnapshotSynchronizer,
                reviewMedicationsUseCase: reviewMedicationsUseCase,
                addMedicationAndScheduleUseCase: addMedicationAndScheduleUseCase,
                updateMedicationAndRescheduleUseCase: updateMedicationAndRescheduleUseCase,
                deactivateMedicationUseCase: deactivateMedicationUseCase,
                deleteMedicationUseCase: deleteMedicationUseCase
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicationManagementDependencies)
                .task {
                    await medicationManagementDependencies.widgetSnapshotSynchronizer.sync(referenceDate: Date())
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        return
                    }

                    Task {
                        await medicationManagementDependencies.widgetSnapshotSynchronizer.sync(referenceDate: Date())
                    }
                }
        }
    }
}
