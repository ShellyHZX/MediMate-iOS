import Foundation
import Testing
@testable import MediMate

struct DeleteMedicationUseCaseTests {
    @Test func medicationWithOnlyUpcomingAndDueDosesCanBeDeleted() async throws {
        let environment = try makeEnvironment()
        let upcomingDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B101"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
            status: .upcoming
        )
        let dueDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B102"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 12, 0),
            status: .due
        )
        environment.scheduledDoseRepository.scheduledDosesInRange = [upcomingDose, dueDose]
        environment.scheduledDoseRepository.scheduledDoseByID[upcomingDose.id] = upcomingDose
        environment.scheduledDoseRepository.scheduledDoseByID[dueDose.id] = dueDose

        try await environment.useCase.execute(medicationID: environment.medication.id)

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[upcomingDose.id, dueDose.id]])
        #expect(environment.medicationRepository.deletedMedicationIDs == [environment.medication.id])
        #expect(environment.medicationRepository.medicationByID[environment.medication.id] == nil)
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[upcomingDose.id] == nil)
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[dueDose.id] == nil)
    }

    @Test func recordedDoseHistoryBlocksDeletionWithoutDeletingAnything() async throws {
        for status in [DoseStatus.taken, .skipped, .missed] {
            let environment = try makeEnvironment()
            let historicalDose = try makeScheduledDose(
                id: UUID(),
                medicationID: environment.medication.id,
                scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
                status: status,
                takenAt: status == .taken ? TestDates.date(2026, 7, 1, 8, 5) : nil
            )
            environment.scheduledDoseRepository.scheduledDosesInRange = [historicalDose]
            environment.scheduledDoseRepository.scheduledDoseByID[historicalDose.id] = historicalDose

            await expectThrows(DeleteMedicationUseCaseError.recordedHistoryExists) {
                try await environment.useCase.execute(medicationID: environment.medication.id)
            }

            #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs.isEmpty)
            #expect(environment.medicationRepository.deletedMedicationIDs.isEmpty)
            #expect(environment.medicationRepository.medicationByID[environment.medication.id] == environment.medication)
            #expect(environment.scheduledDoseRepository.scheduledDoseByID[historicalDose.id] == historicalDose)
        }
    }

    @Test func unrelatedMedicationAndDosesRemainUntouched() async throws {
        let environment = try makeEnvironment()
        let deletedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B201"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
            status: .upcoming
        )
        let unrelatedMedication = try makeMedication(id: uuid("00000000-0000-0000-0000-00000000B2FF"))
        let unrelatedDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B202"),
            medicationID: unrelatedMedication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
            status: .upcoming
        )
        environment.medicationRepository.medicationByID[unrelatedMedication.id] = unrelatedMedication
        environment.scheduledDoseRepository.scheduledDosesInRange = [deletedDose, unrelatedDose]
        environment.scheduledDoseRepository.scheduledDoseByID[deletedDose.id] = deletedDose
        environment.scheduledDoseRepository.scheduledDoseByID[unrelatedDose.id] = unrelatedDose

        try await environment.useCase.execute(medicationID: environment.medication.id)

        #expect(environment.medicationRepository.medicationByID[unrelatedMedication.id] == unrelatedMedication)
        #expect(environment.scheduledDoseRepository.scheduledDoseByID[unrelatedDose.id] == unrelatedDose)
    }

    @Test func medicationNotFoundMapsToTypedError() async throws {
        let environment = try makeEnvironment()
        let missingID = uuid("00000000-0000-0000-0000-00000000B301")

        await expectThrows(DeleteMedicationUseCaseError.medicationNotFound) {
            try await environment.useCase.execute(medicationID: missingID)
        }

        #expect(environment.scheduledDoseRepository.fetchedScheduledDoseMedicationIDs.isEmpty)
        #expect(environment.medicationRepository.deletedMedicationIDs.isEmpty)
    }

    @Test func doseDeletionFailurePreventsMedicationDeletion() async throws {
        let environment = try makeEnvironment()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B401"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
            status: .upcoming
        )
        environment.scheduledDoseRepository.scheduledDosesInRange = [dose]
        environment.scheduledDoseRepository.deleteScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure

        await expectThrows(DeleteMedicationUseCaseError.deleteScheduledDosesFailure) {
            try await environment.useCase.execute(medicationID: environment.medication.id)
        }

        #expect(environment.medicationRepository.deletedMedicationIDs.isEmpty)
    }

    @Test func medicationDeletionFailureMapsToTypedErrorAfterDoseDeletion() async throws {
        let environment = try makeEnvironment()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000B501"),
            medicationID: environment.medication.id,
            scheduledAt: TestDates.date(2026, 7, 1, 8, 0),
            status: .upcoming
        )
        environment.scheduledDoseRepository.scheduledDosesInRange = [dose]
        environment.medicationRepository.deleteMedicationError = MockMedicationRepositoryError.requestedFailure

        await expectThrows(DeleteMedicationUseCaseError.deleteMedicationFailure) {
            try await environment.useCase.execute(medicationID: environment.medication.id)
        }

        #expect(environment.scheduledDoseRepository.deletedScheduledDoseIDs == [[dose.id]])
    }

    private func makeEnvironment() throws -> DeleteMedicationUseCaseTestEnvironment {
        let medicationRepository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let medication = try makeMedication(id: uuid("00000000-0000-0000-0000-00000000B000"))
        medicationRepository.medicationByID[medication.id] = medication

        return DeleteMedicationUseCaseTestEnvironment(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository,
            medication: medication,
            useCase: DeleteMedicationUseCase(
                medicationRepository: medicationRepository,
                scheduledDoseRepository: scheduledDoseRepository
            )
        )
    }

    private func makeMedication(id: UUID) throws -> Medication {
        let doseTime = try #require(DoseTime(hour: 8, minute: 0))
        let schedule = try #require(DoseSchedule(dailyDoseTimes: [doseTime]))
        let dosage = try #require(Dosage(amount: 1, unit: .tablet))

        return Medication(
            id: id,
            name: "Vitamin D",
            dosage: dosage,
            schedule: schedule,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

private struct DeleteMedicationUseCaseTestEnvironment {
    let medicationRepository: MockMedicationRepository
    let scheduledDoseRepository: MockScheduledDoseRepository
    let medication: Medication
    let useCase: DeleteMedicationUseCase
}
