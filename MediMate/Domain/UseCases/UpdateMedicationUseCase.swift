import Foundation

struct UpdateMedicationInput: Equatable {
    let medicationID: UUID
    let name: String
    let dosageAmount: Decimal
    let dosageUnit: DosageUnit
    let instructions: String?
    let dailyDoseTimes: [DoseTime]

    init(
        medicationID: UUID,
        name: String,
        dosageAmount: Decimal,
        dosageUnit: DosageUnit,
        instructions: String? = nil,
        dailyDoseTimes: [DoseTime]
    ) {
        self.medicationID = medicationID
        self.name = name
        self.dosageAmount = dosageAmount
        self.dosageUnit = dosageUnit
        self.instructions = instructions
        self.dailyDoseTimes = dailyDoseTimes
    }
}

enum UpdateMedicationUseCaseError: Error, Equatable {
    case medicationNotFound
    case blankName
    case invalidDosage
    case emptyDoseTimes
    case duplicateDoseTimes
    case invalidSchedule
    case persistenceFailure
}

struct UpdateMedicationUseCase {
    private let medicationRepository: MedicationRepository
    private let validator = MedicationInputValidator()

    init(medicationRepository: MedicationRepository) {
        self.medicationRepository = medicationRepository
    }

    func execute(input: UpdateMedicationInput) async throws -> Medication {
        let existingMedication: Medication

        do {
            guard let fetchedMedication = try await medicationRepository.fetchMedication(id: input.medicationID) else {
                throw UpdateMedicationUseCaseError.medicationNotFound
            }

            existingMedication = fetchedMedication
        } catch let error as UpdateMedicationUseCaseError {
            throw error
        } catch {
            throw UpdateMedicationUseCaseError.persistenceFailure
        }

        let validatedInput: ValidatedMedicationInput

        do {
            validatedInput = try validator.validate(
                name: input.name,
                dosageAmount: input.dosageAmount,
                dosageUnit: input.dosageUnit,
                instructions: input.instructions,
                dailyDoseTimes: input.dailyDoseTimes
            )
        } catch let error as MedicationInputValidationFailure {
            throw mapValidationFailure(error)
        }

        let updatedMedication = Medication(
            id: existingMedication.id,
            name: validatedInput.name,
            dosage: validatedInput.dosage,
            instructions: validatedInput.instructions,
            schedule: validatedInput.schedule,
            isActive: existingMedication.isActive,
            createdAt: existingMedication.createdAt
        )

        do {
            try await medicationRepository.saveMedication(updatedMedication)
            return updatedMedication
        } catch {
            throw UpdateMedicationUseCaseError.persistenceFailure
        }
    }

    private func mapValidationFailure(_ error: MedicationInputValidationFailure) -> UpdateMedicationUseCaseError {
        switch error {
        case .blankName:
            return .blankName
        case .invalidDosage:
            return .invalidDosage
        case .emptyDoseTimes:
            return .emptyDoseTimes
        case .duplicateDoseTimes:
            return .duplicateDoseTimes
        case .invalidSchedule:
            return .invalidSchedule
        }
    }
}
