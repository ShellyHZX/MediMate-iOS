import Foundation

enum DeactivateMedicationUseCaseError: Error, Equatable {
    case medicationNotFound
    case alreadyInactive
    case persistenceFailure
}

struct DeactivateMedicationUseCase {
    private let medicationRepository: MedicationRepository

    init(medicationRepository: MedicationRepository) {
        self.medicationRepository = medicationRepository
    }

    func execute(medicationID: UUID) async throws -> Medication {
        let medication: Medication

        do {
            guard let fetchedMedication = try await medicationRepository.fetchMedication(id: medicationID) else {
                throw DeactivateMedicationUseCaseError.medicationNotFound
            }

            medication = fetchedMedication
        } catch let error as DeactivateMedicationUseCaseError {
            throw error
        } catch {
            throw DeactivateMedicationUseCaseError.persistenceFailure
        }

        guard medication.isActive else {
            throw DeactivateMedicationUseCaseError.alreadyInactive
        }

        let deactivatedMedication = Medication(
            id: medication.id,
            name: medication.name,
            dosage: medication.dosage,
            instructions: medication.instructions,
            schedule: medication.schedule,
            isActive: false,
            createdAt: medication.createdAt
        )

        do {
            try await medicationRepository.saveMedication(deactivatedMedication)
            return deactivatedMedication
        } catch {
            throw DeactivateMedicationUseCaseError.persistenceFailure
        }
    }
}
