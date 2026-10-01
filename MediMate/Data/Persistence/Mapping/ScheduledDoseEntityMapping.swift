import Foundation

extension ScheduledDoseEntity {
    func toDomainScheduledDose() throws -> ScheduledDose {
        let id = try required(id, entity: "ScheduledDoseEntity", field: "id")
        let medicationID = try required(medicationID, entity: "ScheduledDoseEntity", field: "medicationID")
        let medicationName = try required(medicationName, entity: "ScheduledDoseEntity", field: "medicationName")
        let dosageAmount = try required(dosageAmount, entity: "ScheduledDoseEntity", field: "dosageAmount")
        let dosageUnitRawValue = try required(dosageUnit, entity: "ScheduledDoseEntity", field: "dosageUnit")
        let scheduledAt = try required(scheduledAt, entity: "ScheduledDoseEntity", field: "scheduledAt")
        let statusRawValue = try required(status, entity: "ScheduledDoseEntity", field: "status")

        guard let dosageUnit = DosageUnit(rawValue: dosageUnitRawValue) else {
            throw CoreDataMappingError.invalidDosageUnit(dosageUnitRawValue)
        }

        guard let dosage = Dosage(amount: dosageAmount.decimalValue, unit: dosageUnit) else {
            throw CoreDataMappingError.invalidDosage
        }

        let doseStatus = try DoseStatus(persistedRawValue: statusRawValue)

        return ScheduledDose(
            id: id,
            medicationID: medicationID,
            medicationName: medicationName,
            dosage: dosage,
            scheduledAt: scheduledAt,
            status: doseStatus,
            takenAt: takenAt
        )
    }

    func apply(_ scheduledDose: ScheduledDose) {
        id = scheduledDose.id
        medicationID = scheduledDose.medicationID
        medicationName = scheduledDose.medicationName
        dosageAmount = NSDecimalNumber(decimal: scheduledDose.dosage.amount)
        dosageUnit = scheduledDose.dosage.unit.rawValue
        scheduledAt = scheduledDose.scheduledAt
        status = scheduledDose.status.persistedRawValue
        takenAt = scheduledDose.takenAt
    }
}
