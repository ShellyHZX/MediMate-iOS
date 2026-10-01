import CoreData
import Foundation

extension MedicationEntity {
    func toDomainMedication() throws -> Medication {
        let id = try required(id, entity: "MedicationEntity", field: "id")
        let name = try required(name, entity: "MedicationEntity", field: "name")
        let dosageAmount = try required(dosageAmount, entity: "MedicationEntity", field: "dosageAmount")
        let dosageUnitRawValue = try required(dosageUnit, entity: "MedicationEntity", field: "dosageUnit")
        let createdAt = try required(createdAt, entity: "MedicationEntity", field: "createdAt")

        guard let dosageUnit = DosageUnit(rawValue: dosageUnitRawValue) else {
            throw CoreDataMappingError.invalidDosageUnit(dosageUnitRawValue)
        }

        guard let dosage = Dosage(amount: dosageAmount.decimalValue, unit: dosageUnit) else {
            throw CoreDataMappingError.invalidDosage
        }

        let doseTimes = try (doseTimes as? Set<DoseTimeEntity> ?? [])
            .map { try $0.toDomainDoseTime() }
            .sorted {
                ($0.hour, $0.minute) < ($1.hour, $1.minute)
            }

        guard let schedule = DoseSchedule(dailyDoseTimes: doseTimes) else {
            throw CoreDataMappingError.invalidDoseSchedule
        }

        return Medication(
            id: id,
            name: name,
            dosage: dosage,
            instructions: instructions,
            schedule: schedule,
            isActive: isActive,
            createdAt: createdAt
        )
    }

    func apply(_ medication: Medication) {
        id = medication.id
        name = medication.name
        dosageAmount = NSDecimalNumber(decimal: medication.dosage.amount)
        dosageUnit = medication.dosage.unit.rawValue
        instructions = medication.instructions
        isActive = medication.isActive
        createdAt = medication.createdAt
    }

    func syncDoseTimes(_ domainDoseTimes: [DoseTime], in context: NSManagedObjectContext) {
        let existingDoseTimes = doseTimes as? Set<DoseTimeEntity> ?? []

        for doseTimeEntity in existingDoseTimes {
            removeFromDoseTimes(doseTimeEntity)
            context.delete(doseTimeEntity)
        }

        for doseTime in domainDoseTimes {
            let doseTimeEntity = DoseTimeEntity(context: context)
            doseTimeEntity.apply(doseTime)
            doseTimeEntity.medication = self
            addToDoseTimes(doseTimeEntity)
        }
    }
}
