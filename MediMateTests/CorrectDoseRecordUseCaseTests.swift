import Foundation
import Testing
@testable import MediMate

struct CorrectDoseRecordUseCaseTests {
    @Test func takenToNotTakenOnSameDayAfterScheduledTimeBecomesDue() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A101"),
            scheduledAt: TestDates.date(2026, 6, 10, 8, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 10, 8, 10)
        )
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = makeUseCase(repository: repository)

        let correctedDose = try await useCase.execute(
            scheduledDoseID: dose.id,
            correction: .notTaken,
            referenceDate: TestDates.date(2026, 6, 10, 12, 0)
        )

        #expect(correctedDose.status == .due)
        #expect(correctedDose.takenAt == nil)
        #expect(repository.savedScheduledDoses == [correctedDose])
    }

    @Test func skippedToNotTakenOnSameDayBeforeScheduledTimeBecomesUpcoming() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A201"),
            scheduledAt: TestDates.date(2026, 6, 10, 18, 0),
            status: .skipped
        )
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = makeUseCase(repository: repository)

        let correctedDose = try await useCase.execute(
            scheduledDoseID: dose.id,
            correction: .notTaken,
            referenceDate: TestDates.date(2026, 6, 10, 12, 0)
        )

        #expect(correctedDose.status == .upcoming)
        #expect(correctedDose.takenAt == nil)
    }

    @Test func previousDayCorrectionToNotTakenBecomesMissed() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A301"),
            scheduledAt: TestDates.date(2026, 6, 9, 18, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 9, 18, 5)
        )
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = makeUseCase(repository: repository)

        let correctedDose = try await useCase.execute(
            scheduledDoseID: dose.id,
            correction: .notTaken,
            referenceDate: TestDates.date(2026, 6, 10, 12, 0)
        )

        #expect(correctedDose.status == .missed)
        #expect(correctedDose.takenAt == nil)
    }

    @Test func correctionToTakenSetsTakenAt() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A401"),
            status: .skipped
        )
        let takenAt = TestDates.date(2026, 6, 10, 9, 15)
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = makeUseCase(repository: repository)

        let correctedDose = try await useCase.execute(
            scheduledDoseID: dose.id,
            correction: .taken(at: takenAt),
            referenceDate: TestDates.date(2026, 6, 10, 12, 0)
        )

        #expect(correctedDose.status == .taken)
        #expect(correctedDose.takenAt == takenAt)
    }

    @Test func correctionToSkippedClearsTakenAt() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A501"),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 10, 8, 5)
        )
        repository.scheduledDoseByID[dose.id] = dose
        let useCase = makeUseCase(repository: repository)

        let correctedDose = try await useCase.execute(
            scheduledDoseID: dose.id,
            correction: .skipped,
            referenceDate: TestDates.date(2026, 6, 10, 12, 0)
        )

        #expect(correctedDose.status == .skipped)
        #expect(correctedDose.takenAt == nil)
    }

    @Test func doseNotFoundMapsToTypedError() async {
        let repository = MockScheduledDoseRepository()
        let useCase = makeUseCase(repository: repository)

        await expectThrows(CorrectDoseRecordUseCaseError.doseNotFound) {
            _ = try await useCase.execute(
                scheduledDoseID: uuid("00000000-0000-0000-0000-00000000A601"),
                correction: .notTaken,
                referenceDate: TestDates.date(2026, 6, 10, 12, 0)
            )
        }
    }

    @Test func persistenceFailureMapsToTypedErrorWithoutSavingOtherDoses() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-00000000A701"),
            status: .taken,
            takenAt: TestDates.date(2026, 6, 10, 8, 5)
        )
        repository.scheduledDoseByID[dose.id] = dose
        repository.saveScheduledDoseError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = makeUseCase(repository: repository)

        await expectThrows(CorrectDoseRecordUseCaseError.persistenceFailure) {
            _ = try await useCase.execute(
                scheduledDoseID: dose.id,
                correction: .notTaken,
                referenceDate: TestDates.date(2026, 6, 10, 12, 0)
            )
        }

        #expect(repository.savedScheduledDoses.isEmpty)
    }

    private func makeUseCase(repository: MockScheduledDoseRepository) -> CorrectDoseRecordUseCase {
        CorrectDoseRecordUseCase(
            scheduledDoseRepository: repository,
            calendar: TestDates.calendar
        )
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
