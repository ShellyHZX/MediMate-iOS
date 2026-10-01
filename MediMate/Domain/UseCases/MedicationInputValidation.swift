import Foundation

enum MedicationInputValidationFailure: Error, Equatable {
    case blankName
    case invalidDosage
    case emptyDoseTimes
    case duplicateDoseTimes
    case invalidSchedule
}

struct ValidatedMedicationInput {
    let name: String
    let dosage: Dosage
    let instructions: String?
    let schedule: DoseSchedule
}

struct MedicationInputValidator {
    func validate(
        name: String,
        dosageAmount: Decimal,
        dosageUnit: DosageUnit,
        instructions: String?,
        dailyDoseTimes: [DoseTime]
    ) throws -> ValidatedMedicationInput {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw MedicationInputValidationFailure.blankName
        }

        guard let dosage = Dosage(amount: dosageAmount, unit: dosageUnit) else {
            throw MedicationInputValidationFailure.invalidDosage
        }

        guard !dailyDoseTimes.isEmpty else {
            throw MedicationInputValidationFailure.emptyDoseTimes
        }

        guard Set(dailyDoseTimes).count == dailyDoseTimes.count else {
            throw MedicationInputValidationFailure.duplicateDoseTimes
        }

        guard let schedule = DoseSchedule(dailyDoseTimes: dailyDoseTimes) else {
            throw MedicationInputValidationFailure.invalidSchedule
        }

        let normalizedInstructions = instructions?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        return ValidatedMedicationInput(
            name: trimmedName,
            dosage: dosage,
            instructions: normalizedInstructions,
            schedule: schedule
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
