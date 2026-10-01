import Foundation
import Testing
@testable import MediMate

struct ReviewMedicationsUseCaseTests {
    @Test func returnsMedicationsFromRepositoryIncludingInactiveMedication() async throws {
        let repository = MockMedicationRepository()
        let activeMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004001"),
            name: "Active Medication",
            isActive: true
        )
        let inactiveMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004002"),
            name: "Inactive Medication",
            isActive: false
        )
        repository.medications = [inactiveMedication, activeMedication]
        let useCase = ReviewMedicationsUseCase(medicationRepository: repository)

        let medications = try await useCase.execute()

        #expect(medications == [inactiveMedication, activeMedication])
        #expect(repository.fetchedAllMedicationsCount == 1)
    }

    @Test func fetchAllFailureMapsToPersistenceFailure() async throws {
        let repository = MockMedicationRepository()
        repository.fetchAllMedicationsError = MockMedicationRepositoryError.requestedFailure
        let useCase = ReviewMedicationsUseCase(medicationRepository: repository)

        await expectThrows(ReviewMedicationsUseCaseError.persistenceFailure) {
            _ = try await useCase.execute()
        }
    }
}

struct AddMedicationUseCaseTests {
    @Test func validInputCreatesAndSavesExpectedMedication() async throws {
        let repository = MockMedicationRepository()
        let medicationID = uuid("00000000-0000-0000-0000-000000004101")
        let createdAt = TestDates.date(2026, 2, 1, 9, 0)
        let useCase = AddMedicationUseCase(
            medicationRepository: repository,
            uuidFactory: { medicationID },
            dateFactory: { createdAt }
        )
        let input = try makeAddInput(
            name: "Vitamin D",
            dosageAmount: 2,
            dosageUnit: .tablet,
            instructions: "Take with food",
            doseTimes: [(8, 0), (20, 0)]
        )

        let medication = try await useCase.execute(input: input)
        let expectedDosage = try #require(Dosage(amount: 2, unit: .tablet))

        #expect(medication.id == medicationID)
        #expect(medication.name == "Vitamin D")
        #expect(medication.dosage == expectedDosage)
        #expect(medication.instructions == "Take with food")
        #expect(medication.schedule.dailyDoseTimes == input.dailyDoseTimes)
        #expect(medication.isActive)
        #expect(medication.createdAt == createdAt)
        #expect(repository.savedMedications == [medication])
    }

    @Test func trimsMedicationNameBeforeSaving() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let input = try makeAddInput(name: "  Vitamin D\n")

        let medication = try await useCase.execute(input: input)

        #expect(medication.name == "Vitamin D")
        #expect(repository.savedMedications.first?.name == "Vitamin D")
    }

    @Test func whitespaceOnlyNameFailsWithoutSaving() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let input = try makeAddInput(name: " \n\t ")

        await expectThrows(AddMedicationUseCaseError.blankName) {
            _ = try await useCase.execute(input: input)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func zeroOrNegativeDosageFailsWithoutSaving() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let zeroDosageInput = try makeAddInput(dosageAmount: 0)
        let negativeDosageInput = try makeAddInput(dosageAmount: -1)

        await expectThrows(AddMedicationUseCaseError.invalidDosage) {
            _ = try await useCase.execute(input: zeroDosageInput)
        }

        await expectThrows(AddMedicationUseCaseError.invalidDosage) {
            _ = try await useCase.execute(input: negativeDosageInput)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func emptyScheduleFailsWithoutSaving() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let input = AddMedicationInput(
            name: "Vitamin D",
            dosageAmount: 1,
            dosageUnit: .tablet,
            dailyDoseTimes: []
        )

        await expectThrows(AddMedicationUseCaseError.emptyDoseTimes) {
            _ = try await useCase.execute(input: input)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func duplicateDoseTimesFailWithoutSaving() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let doseTime = try #require(DoseTime(hour: 8, minute: 0))
        let input = AddMedicationInput(
            name: "Vitamin D",
            dosageAmount: 1,
            dosageUnit: .tablet,
            dailyDoseTimes: [doseTime, doseTime]
        )

        await expectThrows(AddMedicationUseCaseError.duplicateDoseTimes) {
            _ = try await useCase.execute(input: input)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func whitespaceOnlyInstructionsNormalizeToNil() async throws {
        let repository = MockMedicationRepository()
        let useCase = makeUseCase(repository: repository)
        let input = try makeAddInput(instructions: " \n\t ")

        let medication = try await useCase.execute(input: input)

        #expect(medication.instructions == nil)
        #expect(repository.savedMedications.first?.instructions == nil)
    }

    @Test func saveFailureMapsToPersistenceFailure() async throws {
        let repository = MockMedicationRepository()
        repository.saveMedicationError = MockMedicationRepositoryError.requestedFailure
        let useCase = makeUseCase(repository: repository)
        let input = try makeAddInput()

        await expectThrows(AddMedicationUseCaseError.persistenceFailure) {
            _ = try await useCase.execute(input: input)
        }
    }

    private func makeUseCase(repository: MockMedicationRepository) -> AddMedicationUseCase {
        AddMedicationUseCase(
            medicationRepository: repository,
            uuidFactory: { uuid("00000000-0000-0000-0000-000000004199") },
            dateFactory: { TestDates.date(2026, 2, 1, 9, 0) }
        )
    }
}

struct UpdateMedicationUseCaseTests {
    @Test func validUpdatePreservesIDCreatedAtAndIsActive() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004201"),
            name: "Original",
            isActive: false,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        repository.medicationByID[existingMedication.id] = existingMedication
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(
            medicationID: existingMedication.id,
            name: "Updated",
            dosageAmount: 2,
            dosageUnit: .capsule,
            instructions: "Updated instructions",
            doseTimes: [(12, 0)]
        )

        let updatedMedication = try await useCase.execute(input: input)

        #expect(updatedMedication.id == existingMedication.id)
        #expect(updatedMedication.createdAt == existingMedication.createdAt)
        #expect(updatedMedication.isActive == existingMedication.isActive)
    }

    @Test func editableFieldsAreUpdatedAndSaved() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004202"),
            name: "Original"
        )
        repository.medicationByID[existingMedication.id] = existingMedication
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(
            medicationID: existingMedication.id,
            name: " Updated Name ",
            dosageAmount: 500,
            dosageUnit: .mg,
            instructions: " Take nightly ",
            doseTimes: [(21, 30), (8, 15)]
        )

        let updatedMedication = try await useCase.execute(input: input)
        let expectedDosage = try #require(Dosage(amount: 500, unit: .mg))
        let expectedMorningDoseTime = try #require(DoseTime(hour: 8, minute: 15))
        let expectedEveningDoseTime = try #require(DoseTime(hour: 21, minute: 30))

        #expect(updatedMedication.name == "Updated Name")
        #expect(updatedMedication.dosage == expectedDosage)
        #expect(updatedMedication.instructions == "Take nightly")
        #expect(updatedMedication.schedule.dailyDoseTimes == [
            expectedMorningDoseTime,
            expectedEveningDoseTime
        ])
        #expect(repository.savedMedications == [updatedMedication])
    }

    @Test func missingMedicationReturnsMedicationNotFound() async throws {
        let repository = MockMedicationRepository()
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(medicationID: uuid("00000000-0000-0000-0000-000000004203"))

        await expectThrows(UpdateMedicationUseCaseError.medicationNotFound) {
            _ = try await useCase.execute(input: input)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func invalidInputIsRejectedWithoutSaving() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000004204"))
        repository.medicationByID[existingMedication.id] = existingMedication
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(
            medicationID: existingMedication.id,
            name: "\n ",
            dosageAmount: 1
        )

        await expectThrows(UpdateMedicationUseCaseError.blankName) {
            _ = try await useCase.execute(input: input)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func repositoryFailureMapsToPersistenceFailure() async throws {
        let repository = MockMedicationRepository()
        repository.fetchMedicationError = MockMedicationRepositoryError.requestedFailure
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(medicationID: uuid("00000000-0000-0000-0000-000000004205"))

        await expectThrows(UpdateMedicationUseCaseError.persistenceFailure) {
            _ = try await useCase.execute(input: input)
        }
    }

    @Test func updateDoesNotCreateNewIdentity() async throws {
        let repository = MockMedicationRepository()
        let existingMedication = try makeMedication(id: uuid("00000000-0000-0000-0000-000000004206"))
        repository.medicationByID[existingMedication.id] = existingMedication
        let useCase = UpdateMedicationUseCase(medicationRepository: repository)
        let input = try makeUpdateInput(medicationID: existingMedication.id, name: "New Name")

        let updatedMedication = try await useCase.execute(input: input)

        #expect(updatedMedication.id == existingMedication.id)
        #expect(repository.savedMedications.map(\.id) == [existingMedication.id])
    }
}

struct DeactivateMedicationUseCaseTests {
    @Test func activeMedicationBecomesInactiveAndIsSaved() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004301"),
            isActive: true
        )
        repository.medicationByID[medication.id] = medication
        let useCase = DeactivateMedicationUseCase(medicationRepository: repository)

        let deactivatedMedication = try await useCase.execute(medicationID: medication.id)

        #expect(!deactivatedMedication.isActive)
        #expect(repository.savedMedications == [deactivatedMedication])
    }

    @Test func deactivationPreservesAllOtherMedicationValues() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004302"),
            name: "Medication A",
            dosage: Dosage(amount: 500, unit: .mg),
            instructions: "Take with food",
            doseTimes: [(8, 0), (20, 0)],
            isActive: true,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
        repository.medicationByID[medication.id] = medication
        let useCase = DeactivateMedicationUseCase(medicationRepository: repository)

        let deactivatedMedication = try await useCase.execute(medicationID: medication.id)

        #expect(deactivatedMedication.id == medication.id)
        #expect(deactivatedMedication.name == medication.name)
        #expect(deactivatedMedication.dosage == medication.dosage)
        #expect(deactivatedMedication.instructions == medication.instructions)
        #expect(deactivatedMedication.schedule == medication.schedule)
        #expect(deactivatedMedication.createdAt == medication.createdAt)
    }

    @Test func missingMedicationReturnsMedicationNotFound() async throws {
        let repository = MockMedicationRepository()
        let useCase = DeactivateMedicationUseCase(medicationRepository: repository)

        await expectThrows(DeactivateMedicationUseCaseError.medicationNotFound) {
            _ = try await useCase.execute(medicationID: uuid("00000000-0000-0000-0000-000000004303"))
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func alreadyInactiveReturnsAlreadyInactive() async throws {
        let repository = MockMedicationRepository()
        let medication = try makeMedication(
            id: uuid("00000000-0000-0000-0000-000000004304"),
            isActive: false
        )
        repository.medicationByID[medication.id] = medication
        let useCase = DeactivateMedicationUseCase(medicationRepository: repository)

        await expectThrows(DeactivateMedicationUseCaseError.alreadyInactive) {
            _ = try await useCase.execute(medicationID: medication.id)
        }

        #expect(repository.savedMedications.isEmpty)
    }

    @Test func repositoryFailureMapsToPersistenceFailure() async throws {
        let repository = MockMedicationRepository()
        repository.fetchMedicationError = MockMedicationRepositoryError.requestedFailure
        let useCase = DeactivateMedicationUseCase(medicationRepository: repository)

        await expectThrows(DeactivateMedicationUseCaseError.persistenceFailure) {
            _ = try await useCase.execute(medicationID: uuid("00000000-0000-0000-0000-000000004305"))
        }
    }
}

private func makeAddInput(
    name: String = "Vitamin D",
    dosageAmount: Decimal = 1,
    dosageUnit: DosageUnit = .tablet,
    instructions: String? = nil,
    doseTimes: [(hour: Int, minute: Int)] = [(8, 0)]
) throws -> AddMedicationInput {
    AddMedicationInput(
        name: name,
        dosageAmount: dosageAmount,
        dosageUnit: dosageUnit,
        instructions: instructions,
        dailyDoseTimes: try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
    )
}

private func makeUpdateInput(
    medicationID: UUID,
    name: String = "Vitamin D",
    dosageAmount: Decimal = 1,
    dosageUnit: DosageUnit = .tablet,
    instructions: String? = nil,
    doseTimes: [(hour: Int, minute: Int)] = [(8, 0)]
) throws -> UpdateMedicationInput {
    UpdateMedicationInput(
        medicationID: medicationID,
        name: name,
        dosageAmount: dosageAmount,
        dosageUnit: dosageUnit,
        instructions: instructions,
        dailyDoseTimes: try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
    )
}

private func makeMedication(
    id: UUID = uuid("00000000-0000-0000-0000-000000004999"),
    name: String = "Vitamin D",
    dosage: Dosage? = Dosage(amount: 1, unit: .tablet),
    instructions: String? = nil,
    doseTimes: [(hour: Int, minute: Int)] = [(8, 0)],
    isActive: Bool = true,
    createdAt: Date = TestDates.date(2026, 1, 1, 9, 0)
) throws -> Medication {
    let dailyDoseTimes = try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
    let schedule = try #require(DoseSchedule(dailyDoseTimes: dailyDoseTimes))

    return Medication(
        id: id,
        name: name,
        dosage: try #require(dosage),
        instructions: instructions,
        schedule: schedule,
        isActive: isActive,
        createdAt: createdAt
    )
}

private func uuid(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
