import SwiftUI

@main
struct MediMateApp: App {
    private let persistenceController: PersistenceController
    @StateObject private var medicationManagementDependencies: MedicationManagementDependencies

    init() {
        let persistenceController = PersistenceController.shared
        let medicationRepository = CoreDataMedicationRepository(context: persistenceController.viewContext)
        let reviewMedicationsUseCase = ReviewMedicationsUseCase(medicationRepository: medicationRepository)

        self.persistenceController = persistenceController
        _medicationManagementDependencies = StateObject(
            wrappedValue: MedicationManagementDependencies(reviewMedicationsUseCase: reviewMedicationsUseCase)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicationManagementDependencies)
        }
    }
}
