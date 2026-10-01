import Foundation
import Testing
@testable import MediMate

struct RecordDoseAsTakenUseCaseTests {
    @Test func dueDoseTransitionsToTakenAndIsSaved() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .due)
        repository.scheduledDoseByID[dose.id] = dose
        let takenAt = TestDates.date(2026, 1, 10, 8, 30)
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        let updatedDose = try await useCase.execute(scheduledDoseID: dose.id, takenAt: takenAt)

        #expect(updatedDose.id == dose.id)
        #expect(updatedDose.medicationID == dose.medicationID)
        #expect(updatedDose.scheduledAt == dose.scheduledAt)
        #expect(updatedDose.status == .taken)
        #expect(updatedDose.takenAt == takenAt)
        #expect(repository.savedScheduledDoses == [updatedDose])
    }

    @Test func missedDoseTransitionsToTaken() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .missed)
        repository.scheduledDoseByID[dose.id] = dose
        let takenAt = TestDates.date(2026, 1, 10, 9, 0)
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        let updatedDose = try await useCase.execute(scheduledDoseID: dose.id, takenAt: takenAt)

        #expect(updatedDose.status == .taken)
        #expect(updatedDose.takenAt == takenAt)
        #expect(repository.savedScheduledDoses == [updatedDose])
    }

    @Test func alreadyTakenDoseThrowsWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .taken, takenAt: TestDates.date(2026, 1, 10, 8, 10))
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordDoseAsTakenUseCaseError.alreadyTaken) {
            try await useCase.execute(scheduledDoseID: dose.id, takenAt: TestDates.date(2026, 1, 10, 8, 30))
        }

        #expect(repository.savedScheduledDoses.isEmpty)
    }

    @Test func skippedDoseThrowsWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .skipped)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordDoseAsTakenUseCaseError.doseWasSkipped) {
            try await useCase.execute(scheduledDoseID: dose.id, takenAt: TestDates.date(2026, 1, 10, 8, 30))
        }

        #expect(repository.savedScheduledDoses.isEmpty)
    }

    @Test func missingDoseThrowsDoseNotFound() async throws {
        let repository = MockScheduledDoseRepository()
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordDoseAsTakenUseCaseError.doseNotFound) {
            try await useCase.execute(
                scheduledDoseID: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
                takenAt: TestDates.date(2026, 1, 10, 8, 30)
            )
        }
    }

    @Test func fetchFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDoseError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordDoseAsTakenUseCaseError.persistenceFailure) {
            try await useCase.execute(
                scheduledDoseID: UUID(uuidString: "00000000-0000-0000-0000-000000000405")!,
                takenAt: TestDates.date(2026, 1, 10, 8, 30)
            )
        }
    }

    @Test func saveFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.saveScheduledDoseError = MockScheduledDoseRepositoryError.requestedFailure
        let dose = try makeScheduledDose(status: .due)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = RecordDoseAsTakenUseCase(scheduledDoseRepository: repository)

        await expectThrows(RecordDoseAsTakenUseCaseError.persistenceFailure) {
            try await useCase.execute(scheduledDoseID: dose.id, takenAt: TestDates.date(2026, 1, 10, 8, 30))
        }
    }
}
