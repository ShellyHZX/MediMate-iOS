import CoreData
import Foundation

struct CoreDataScheduledDoseRepository: ScheduledDoseRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchScheduledDose(id: UUID) async throws -> ScheduledDose? {
        try await context.perform {
            let request = ScheduledDoseEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let scheduledDoseEntity = try context.fetch(request).first else {
                return nil
            }

            return try scheduledDoseEntity.toDomainScheduledDose()
        }
    }

    func fetchScheduledDoses(from startDate: Date, to endDate: Date) async throws -> [ScheduledDose] {
        try await context.perform {
            let request = ScheduledDoseEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "scheduledAt >= %@ AND scheduledAt < %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "scheduledAt", ascending: true)
            ]

            let scheduledDoseEntities = try context.fetch(request)
            let scheduledDoses = try scheduledDoseEntities.map { try $0.toDomainScheduledDose() }

            return scheduledDoses.sorted {
                if $0.scheduledAt == $1.scheduledAt {
                    return $0.id.uuidString < $1.id.uuidString
                }

                return $0.scheduledAt < $1.scheduledAt
            }
        }
    }

    func saveScheduledDose(_ scheduledDose: ScheduledDose) async throws {
        try await context.perform {
            let scheduledDoseEntity = try fetchScheduledDoseEntity(id: scheduledDose.id)
                ?? ScheduledDoseEntity(context: context)

            try apply(scheduledDose, to: scheduledDoseEntity)

            if context.hasChanges {
                try context.save()
            }
        }
    }

    func saveScheduledDoses(_ scheduledDoses: [ScheduledDose]) async throws {
        guard !scheduledDoses.isEmpty else {
            return
        }

        try await context.perform {
            for scheduledDose in scheduledDoses {
                let scheduledDoseEntity = try fetchScheduledDoseEntity(id: scheduledDose.id)
                    ?? ScheduledDoseEntity(context: context)

                try apply(scheduledDose, to: scheduledDoseEntity)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    func deleteScheduledDoses(ids: [UUID]) async throws {
        guard !ids.isEmpty else {
            return
        }

        try await context.perform {
            let request = ScheduledDoseEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)

            let scheduledDoseEntities = try context.fetch(request)

            for scheduledDoseEntity in scheduledDoseEntities {
                context.delete(scheduledDoseEntity)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func apply(_ scheduledDose: ScheduledDose, to scheduledDoseEntity: ScheduledDoseEntity) throws {
        scheduledDoseEntity.apply(scheduledDose)
        scheduledDoseEntity.medication = try fetchMedicationEntity(id: scheduledDose.medicationID)
    }

    private func fetchScheduledDoseEntity(id: UUID) throws -> ScheduledDoseEntity? {
        let request = ScheduledDoseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }

    private func fetchMedicationEntity(id: UUID) throws -> MedicationEntity? {
        let request = MedicationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }
}
