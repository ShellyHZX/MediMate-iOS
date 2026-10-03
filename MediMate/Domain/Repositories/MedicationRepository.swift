import Foundation

protocol MedicationRepository {
    func fetchAllMedications() async throws -> [Medication]
    func fetchMedication(id: UUID) async throws -> Medication?
    func saveMedication(_ medication: Medication) async throws
    func deleteMedication(id: UUID) async throws
}
