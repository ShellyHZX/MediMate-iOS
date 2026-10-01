import Foundation

struct AddMedicationInput: Equatable {
    let name: String
    let dosageAmount: Decimal
    let dosageUnit: DosageUnit
    let instructions: String?
    let dailyDoseTimes: [DoseTime]

    init(
        name: String,
        dosageAmount: Decimal,
        dosageUnit: DosageUnit,
        instructions: String? = nil,
        dailyDoseTimes: [DoseTime]
    ) {
        self.name = name
        self.dosageAmount = dosageAmount
        self.dosageUnit = dosageUnit
        self.instructions = instructions
        self.dailyDoseTimes = dailyDoseTimes
    }
}

enum AddMedicationUseCaseError: Error, Equatable {
    case blankName
    case invalidDosage
    case emptyDoseTimes
    case duplicateDoseTimes
    case invalidSchedule
    case persistenceFailure
}

struct AddMedicationUseCase {
    private let medicationRepository: MedicationRepository
    private let uuidFactory: () -> UUID
    private let dateFactory: () -> Date
    private let validator = MedicationInputValidator()

    init(
        medicationRepository: MedicationRepository,
        uuidFactory: @escaping () -> UUID = UUID.init,
        dateFactory: @escaping () -> Date = Date.init
    ) {
        self.medicationRepository = medicationRepository
        self.uuidFactory = uuidFactory
        self.dateFactory = dateFactory
    }

    func execute(input: AddMedicationInput) async throws -> Medication {
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

        let medication = Medication(
            id: uuidFactory(),
            name: validatedInput.name,
            dosage: validatedInput.dosage,
            instructions: validatedInput.instructions,
            schedule: validatedInput.schedule,
            isActive: true,
            createdAt: dateFactory()
        )

        do {
            try await medicationRepository.saveMedication(medication)
            return medication
        } catch {
            throw AddMedicationUseCaseError.persistenceFailure
        }
    }

    private func mapValidationFailure(_ error: MedicationInputValidationFailure) -> AddMedicationUseCaseError {
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
