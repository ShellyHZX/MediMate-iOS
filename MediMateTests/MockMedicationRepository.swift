import Foundation
@testable import MediMate

enum MockMedicationRepositoryError: Error {
    case requestedFailure
}

final class MockMedicationRepository: MedicationRepository {
    var medications: [Medication] = []
    var medicationByID: [UUID: Medication] = [:]

    var fetchAllMedicationsError: Error?
    var fetchMedicationError: Error?
    var saveMedicationError: Error?

    private(set) var fetchedAllMedicationsCount = 0
    private(set) var fetchedMedicationIDs: [UUID] = []
    private(set) var savedMedications: [Medication] = []

    func fetchAllMedications() async throws -> [Medication] {
        fetchedAllMedicationsCount += 1

        if let fetchAllMedicationsError {
            throw fetchAllMedicationsError
        }

        return medications
    }

    func fetchMedication(id: UUID) async throws -> Medication? {
        fetchedMedicationIDs.append(id)

        if let fetchMedicationError {
            throw fetchMedicationError
        }

        return medicationByID[id]
    }

    func saveMedication(_ medication: Medication) async throws {
        if let saveMedicationError {
            throw saveMedicationError
        }

        savedMedications.append(medication)
        medicationByID[medication.id] = medication
    }
}
