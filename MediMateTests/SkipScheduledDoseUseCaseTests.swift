import Foundation
import Testing
@testable import MediMate

struct SkipScheduledDoseUseCaseTests {
    @Test func dueDoseTransitionsToSkippedAndIsSaved() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .due)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        let updatedDose = try await useCase.execute(scheduledDoseID: dose.id)

        #expect(updatedDose.id == dose.id)
        #expect(updatedDose.medicationID == dose.medicationID)
        #expect(updatedDose.medicationName == dose.medicationName)
        #expect(updatedDose.dosage == dose.dosage)
        #expect(updatedDose.scheduledAt == dose.scheduledAt)
        #expect(updatedDose.status == .skipped)
        #expect(updatedDose.takenAt == nil)
        #expect(repository.savedScheduledDoses == [updatedDose])
    }

    @Test func missedDoseTransitionsToSkipped() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .missed)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        let updatedDose = try await useCase.execute(scheduledDoseID: dose.id)

        #expect(updatedDose.status == .skipped)
        #expect(updatedDose.takenAt == nil)
        #expect(repository.savedScheduledDoses == [updatedDose])
    }

    @Test func takenDoseThrowsWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .taken, takenAt: TestDates.date(2026, 1, 10, 8, 10))
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        await expectThrows(SkipScheduledDoseUseCaseError.doseAlreadyTaken) {
            try await useCase.execute(scheduledDoseID: dose.id)
        }

        #expect(repository.savedScheduledDoses.isEmpty)
    }

    @Test func alreadySkippedDoseThrowsWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(status: .skipped)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        await expectThrows(SkipScheduledDoseUseCaseError.doseAlreadySkipped) {
            try await useCase.execute(scheduledDoseID: dose.id)
        }

        #expect(repository.savedScheduledDoses.isEmpty)
    }

    @Test func missingDoseThrowsDoseNotFound() async throws {
        let repository = MockScheduledDoseRepository()
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        await expectThrows(SkipScheduledDoseUseCaseError.doseNotFound) {
            try await useCase.execute(scheduledDoseID: UUID(uuidString: "00000000-0000-0000-0000-000000000504")!)
        }
    }

    @Test func fetchFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDoseError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        await expectThrows(SkipScheduledDoseUseCaseError.persistenceFailure) {
            try await useCase.execute(scheduledDoseID: UUID(uuidString: "00000000-0000-0000-0000-000000000505")!)
        }
    }

    @Test func saveFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.saveScheduledDoseError = MockScheduledDoseRepositoryError.requestedFailure
        let dose = try makeScheduledDose(status: .due)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = SkipScheduledDoseUseCase(scheduledDoseRepository: repository)

        await expectThrows(SkipScheduledDoseUseCaseError.persistenceFailure) {
            try await useCase.execute(scheduledDoseID: dose.id)
        }
    }
}
