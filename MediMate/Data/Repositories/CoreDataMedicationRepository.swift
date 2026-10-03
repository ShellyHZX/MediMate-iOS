import CoreData
import Foundation

struct CoreDataMedicationRepository: MedicationRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAllMedications() async throws -> [Medication] {
        try await context.perform {
            let request = MedicationEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: true),
                NSSortDescriptor(key: "name", ascending: true)
            ]

            let medicationEntities = try context.fetch(request)
            return try medicationEntities.map { try $0.toDomainMedication() }
        }
    }

    func fetchMedication(id: UUID) async throws -> Medication? {
        try await context.perform {
            let request = MedicationEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let medicationEntity = try context.fetch(request).first else {
                return nil
            }

            return try medicationEntity.toDomainMedication()
        }
    }

    func saveMedication(_ medication: Medication) async throws {
        try await context.perform {
            let medicationEntity = try fetchMedicationEntity(id: medication.id)
                ?? MedicationEntity(context: context)

            medicationEntity.apply(medication)
            medicationEntity.syncDoseTimes(medication.schedule.dailyDoseTimes, in: context)

            if context.hasChanges {
                try context.save()
            }
        }
    }

    func deleteMedication(id: UUID) async throws {
        try await context.perform {
            guard let medicationEntity = try fetchMedicationEntity(id: id) else {
                return
            }

            context.delete(medicationEntity)

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func fetchMedicationEntity(id: UUID) throws -> MedicationEntity? {
        let request = MedicationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }
}
