import Foundation
import Testing
@testable import MediMate

struct ReviewMedicationHistoryUseCaseTests {
    private let calendar = TestDates.calendar

    @Test func fetchesThirtyDayWindowBeforeReferenceDate() async throws {
        let repository = MockScheduledDoseRepository()
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)
        let referenceDate = TestDates.date(2026, 5, 30, 14, 30)

        _ = try await useCase.execute(referenceDate: referenceDate)

        #expect(repository.fetchedRangeRequests.count == 1)
        #expect(repository.fetchedRangeRequests.first?.startDate == TestDates.date(2026, 5, 1, 0, 0))
        #expect(repository.fetchedRangeRequests.first?.endDate == referenceDate)
    }

    @Test func includesHistoryStartBoundaryAndExcludesReferenceBoundary() async throws {
        let repository = MockScheduledDoseRepository()
        let historyStartDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009101"),
            scheduledAt: TestDates.date(2026, 5, 1, 0, 0),
            status: .taken
        )
        let atReferenceDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009102"),
            scheduledAt: TestDates.date(2026, 5, 30, 14, 30),
            status: .due
        )
        repository.scheduledDosesInRange = [historyStartDose, atReferenceDose]
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(referenceDate: TestDates.date(2026, 5, 30, 14, 30))

        #expect(doses.map(\.id) == [historyStartDose.id])
    }

    @Test func excludesDosesOutsideThirtyDayWindow() async throws {
        let repository = MockScheduledDoseRepository()
        let outsideWindowDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009201"),
            scheduledAt: TestDates.date(2026, 4, 30, 23, 59),
            status: .taken
        )
        let insideWindowDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009202"),
            scheduledAt: TestDates.date(2026, 5, 1, 8, 0),
            status: .skipped
        )
        repository.scheduledDosesInRange = [outsideWindowDose, insideWindowDose]
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(referenceDate: TestDates.date(2026, 5, 30, 14, 30))

        #expect(doses.map(\.id) == [insideWindowDose.id])
    }

    @Test func returnsNewestFirstWithDeterministicTieBreaker() async throws {
        let repository = MockScheduledDoseRepository()
        let firstSameTimeDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009301"),
            scheduledAt: TestDates.date(2026, 5, 20, 9, 0),
            status: .taken
        )
        let secondSameTimeDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009302"),
            scheduledAt: TestDates.date(2026, 5, 20, 9, 0),
            status: .skipped
        )
        let newestDose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009303"),
            scheduledAt: TestDates.date(2026, 5, 22, 18, 0),
            status: .missed
        )
        repository.scheduledDosesInRange = [secondSameTimeDose, newestDose, firstSameTimeDose]
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(referenceDate: TestDates.date(2026, 5, 30, 14, 30))

        #expect(doses.map(\.id) == [newestDose.id, firstSameTimeDose.id, secondSameTimeDose.id])
    }

    @Test func preservesPersistedSnapshotsAndStatuses() async throws {
        let repository = MockScheduledDoseRepository()
        let dosage = Dosage(amount: 2, unit: .capsule)
        let takenAt = TestDates.date(2026, 5, 12, 8, 12)
        let dose = try makeScheduledDose(
            id: uuid("00000000-0000-0000-0000-000000009401"),
            medicationName: "Archived Name",
            dosage: dosage,
            scheduledAt: TestDates.date(2026, 5, 12, 8, 0),
            status: .taken,
            takenAt: takenAt
        )
        repository.scheduledDosesInRange = [dose]
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(referenceDate: TestDates.date(2026, 5, 30, 14, 30))

        #expect(doses == [dose])
        #expect(repository.savedScheduledDoses.isEmpty)
        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func persistenceFailureMapsToTypedError() async {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = ReviewMedicationHistoryUseCase(scheduledDoseRepository: repository, calendar: calendar)

        await expectThrows(ReviewMedicationHistoryUseCaseError.persistenceFailure) {
            _ = try await useCase.execute(referenceDate: TestDates.date(2026, 5, 30, 14, 30))
        }
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
