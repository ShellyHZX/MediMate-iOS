import Foundation

enum ReviewMedicationsUseCaseError: Error, Equatable {
    case persistenceFailure
}

struct ReviewMedicationsUseCase {
    private let medicationRepository: MedicationRepository

    init(medicationRepository: MedicationRepository) {
        self.medicationRepository = medicationRepository
    }

    func execute() async throws -> [Medication] {
        do {
            return try await medicationRepository.fetchAllMedications()
        } catch {
            throw ReviewMedicationsUseCaseError.persistenceFailure
        }
    }
}
