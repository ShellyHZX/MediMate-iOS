import Foundation
import Testing
@testable import MediMate

struct ScheduleMedicationUseCaseTests {
    private let calendar = TestDates.calendar

    @Test func activeMedicationGeneratesExpectedScheduledDoses() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(doseTimes: [(8, 0), (18, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(
            medication: medication,
            startDate: TestDates.date(2026, 1, 10, 0, 0),
            endDate: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(doses.count == 2)
        #expect(doses.map(\.scheduledAt) == [
            TestDates.date(2026, 1, 10, 8, 0),
            TestDates.date(2026, 1, 10, 18, 0)
        ])
        #expect(doses.allSatisfy { $0.medicationID == medication.id })
        #expect(doses.allSatisfy { $0.medicationName == medication.name })
        #expect(doses.allSatisfy { $0.dosage == medication.dosage })
        #expect(doses.allSatisfy { $0.status == .upcoming })
        #expect(doses.allSatisfy { $0.takenAt == nil })
        #expect(repository.batchSavedScheduledDoses == [doses])
    }

    @Test func inactiveMedicationIsRejectedWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(isActive: false, doseTimes: [(8, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        await expectThrows(ScheduleMedicationUseCaseError.inactiveMedication) {
            try await useCase.execute(
                medication: medication,
                startDate: TestDates.date(2026, 1, 10, 0, 0),
                endDate: TestDates.date(2026, 1, 11, 0, 0)
            )
        }

        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func invalidDateRangeWithEqualStartAndEndIsRejectedWithoutSaving() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(doseTimes: [(8, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)
        let date = TestDates.date(2026, 1, 10, 0, 0)

        await expectThrows(ScheduleMedicationUseCaseError.invalidDateRange) {
            try await useCase.execute(medication: medication, startDate: date, endDate: date)
        }

        #expect(repository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func halfOpenRangeExcludesDoseExactlyAtEndDate() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(doseTimes: [(8, 0), (18, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(
            medication: medication,
            startDate: TestDates.date(2026, 1, 10, 8, 0),
            endDate: TestDates.date(2026, 1, 10, 18, 0)
        )

        #expect(doses.map(\.scheduledAt) == [TestDates.date(2026, 1, 10, 8, 0)])
    }

    @Test func nonMidnightStartDateIsRespected() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(doseTimes: [(8, 0), (18, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(
            medication: medication,
            startDate: TestDates.date(2026, 1, 10, 14, 0),
            endDate: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(doses.map(\.scheduledAt) == [TestDates.date(2026, 1, 10, 18, 0)])
    }

    @Test func generatedDosesAreChronological() async throws {
        let repository = MockScheduledDoseRepository()
        let medication = try makeMedication(doseTimes: [(18, 0), (8, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        let doses = try await useCase.execute(
            medication: medication,
            startDate: TestDates.date(2026, 1, 10, 0, 0),
            endDate: TestDates.date(2026, 1, 11, 0, 0)
        )

        #expect(doses.map(\.scheduledAt) == [
            TestDates.date(2026, 1, 10, 8, 0),
            TestDates.date(2026, 1, 10, 18, 0)
        ])
    }

    @Test func batchSaveFailureMapsToPersistenceFailure() async throws {
        let repository = MockScheduledDoseRepository()
        repository.saveScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let medication = try makeMedication(doseTimes: [(8, 0)])
        let useCase = ScheduleMedicationUseCase(scheduledDoseRepository: repository, calendar: calendar)

        await expectThrows(ScheduleMedicationUseCaseError.persistenceFailure) {
            try await useCase.execute(
                medication: medication,
                startDate: TestDates.date(2026, 1, 10, 0, 0),
                endDate: TestDates.date(2026, 1, 11, 0, 0)
            )
        }
    }

    private func makeMedication(
        isActive: Bool = true,
        doseTimes: [(hour: Int, minute: Int)]
    ) throws -> Medication {
        let dosage = try #require(Dosage(amount: 1, unit: .tablet))
        let times = try doseTimes.map { try #require(DoseTime(hour: $0.hour, minute: $0.minute)) }
        let schedule = try #require(DoseSchedule(dailyDoseTimes: times))

        return Medication(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Vitamin D",
            dosage: dosage,
            instructions: nil,
            schedule: schedule,
            isActive: isActive,
            createdAt: TestDates.date(2026, 1, 1, 9, 0)
        )
    }
}
