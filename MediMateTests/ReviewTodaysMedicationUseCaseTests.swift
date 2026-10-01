import Foundation
import Testing
@testable import MediMate

struct ReviewTodaysMedicationUseCaseTests {
    private let calendar = TestDates.calendar

    @Test func requestsReferenceCalendarDayRangeFromRepository() async throws {
        let repository = MockScheduledDoseRepository()
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)
        let referenceDate = TestDates.date(2026, 1, 10, 14, 30)

        _ = try await useCase.execute(referenceDate: referenceDate)

        #expect(repository.fetchedRangeRequests.count == 1)
        #expect(repository.fetchedRangeRequests.first?.startDate == TestDates.date(2026, 1, 10, 0, 0))
        #expect(repository.fetchedRangeRequests.first?.endDate == TestDates.date(2026, 1, 11, 0, 0))
    }

    @Test func returnedDosesAreChronologicalWhenRepositoryDataIsUnsorted() async throws {
        let repository = MockScheduledDoseRepository()
        let eveningDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .upcoming)
        let morningDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .due)
        repository.scheduledDosesInRange = [eveningDose, morningDose]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.doses.map(\.scheduledAt) == [
            TestDates.date(2026, 1, 10, 8, 0),
            TestDates.date(2026, 1, 10, 18, 0)
        ])
    }

    @Test func unresolvedDoseBeforeOrAtReferenceDateIsRepresentedAsDue() async throws {
        let repository = MockScheduledDoseRepository()
        let beforeReference = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .upcoming)
        let atReference = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 12, 0), status: .missed)
        repository.scheduledDosesInRange = [beforeReference, atReference]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.doses.map(\.status) == [.due, .due])
    }

    @Test func unresolvedDoseAfterReferenceDateIsRepresentedAsUpcoming() async throws {
        let repository = MockScheduledDoseRepository()
        let dose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .due)
        repository.scheduledDosesInRange = [dose]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.doses.first?.status == .upcoming)
    }

    @Test func persistedTakenAndSkippedStatesArePreserved() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 1, 10, 8, 10)
        )
        let skippedDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .skipped)
        repository.scheduledDosesInRange = [takenDose, skippedDose]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.doses.map(\.status) == [.taken, .skipped])
        #expect(summary.doses.first?.takenAt == takenDose.takenAt)
    }

    @Test func transientStatusDerivationDoesNotSave() async throws {
        let repository = MockScheduledDoseRepository()
        repository.scheduledDosesInRange = [
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .upcoming)
        ]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        _ = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(repository.savedScheduledDoses.isEmpty)
        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func completedCountCountsOnlyTakenDoses() async throws {
        let repository = MockScheduledDoseRepository()
        repository.scheduledDosesInRange = [
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .taken),
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 12, 0), status: .skipped),
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .due)
        ]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 14, 0))

        #expect(summary.completedCount == 1)
        #expect(summary.totalCount == 3)
    }

    @Test func priorityDoseCanBeEarliestDueDoseBeforeUpcomingDose() async throws {
        let repository = MockScheduledDoseRepository()
        let dueDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .upcoming)
        let upcomingDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .upcoming)
        repository.scheduledDosesInRange = [upcomingDose, dueDose]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.priorityDose?.id == dueDose.id)
        #expect(summary.priorityDose?.status == .due)
    }

    @Test func priorityDoseFallsBackToEarliestUpcomingActionableDose() async throws {
        let repository = MockScheduledDoseRepository()
        let takenDose = try makeScheduledDose(
            scheduledAt: TestDates.date(2026, 1, 10, 8, 0),
            status: .taken,
            takenAt: TestDates.date(2026, 1, 10, 8, 10)
        )
        let upcomingDose = try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .upcoming)
        repository.scheduledDosesInRange = [upcomingDose, takenDose]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.priorityDose?.id == upcomingDose.id)
        #expect(summary.priorityDose?.status == .upcoming)
    }

    @Test func priorityDoseIsNilWhenEveryDoseIsTakenOrSkipped() async throws {
        let repository = MockScheduledDoseRepository()
        repository.scheduledDosesInRange = [
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 8, 0), status: .taken),
            try makeScheduledDose(scheduledAt: TestDates.date(2026, 1, 10, 18, 0), status: .skipped)
        ]
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let summary = try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))

        #expect(summary.priorityDose == nil)
    }

    @Test func fetchFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.fetchScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = ReviewTodaysMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        await expectThrows(ReviewTodaysMedicationUseCaseError.persistenceFailure) {
            try await useCase.execute(referenceDate: TestDates.date(2026, 1, 10, 12, 0))
        }
    }
}
