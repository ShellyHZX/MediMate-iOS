import Foundation
import Testing
@testable import MediMate

struct AddMedicationAndScheduleUseCaseTests {
    @Test func validAddCreatesMedicationAndGeneratesScheduledDoses() async throws {
        let medicationRepository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let useCase = makeUseCase(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository
        )
        let input = try makeAddInput(doseTimes: [(8, 0)])

        let result = try await useCase.execute(
            input: input,
            referenceDate: TestDates.date(2026, 4, 3, 13, 45)
        )

        #expect(medicationRepository.savedMedications == [result.medication])
        #expect(result.scheduledDoses.count == 14)
        #expect(scheduledDoseRepository.batchSavedScheduledDoses == [result.scheduledDoses])
        #expect(result.scheduledDoses.allSatisfy { $0.medicationID == result.medication.id })
    }

    @Test func generatedWindowStartsAtCalendarStartOfReferenceDay() async throws {
        let useCase = makeUseCase()
        let referenceDate = TestDates.date(2026, 4, 3, 13, 45)
        let input = try makeAddInput(doseTimes: [(0, 0)])

        let result = try await useCase.execute(input: input, referenceDate: referenceDate)

        #expect(result.scheduledDoses.first?.scheduledAt == TestDates.calendar.startOfDay(for: referenceDate))
    }

    @Test func generatedWindowEndsFourteenCalendarDaysLater() async throws {
        let useCase = makeUseCase()
        let startDate = TestDates.date(2026, 4, 3, 0, 0)
        let endDate = try #require(TestDates.calendar.date(byAdding: .day, value: 14, to: startDate))
        let lastExpectedDoseDate = try #require(TestDates.calendar.date(byAdding: .day, value: 13, to: startDate))
        let input = try makeAddInput(doseTimes: [(0, 0)])

        let result = try await useCase.execute(
            input: input,
            referenceDate: TestDates.date(2026, 4, 3, 13, 45)
        )

        #expect(result.scheduledDoses.count == 14)
        #expect(result.scheduledDoses.last?.scheduledAt == lastExpectedDoseDate)
        #expect(!result.scheduledDoses.contains { $0.scheduledAt == endDate })
        #expect(result.scheduledDoses.allSatisfy { $0.scheduledAt < endDate })
    }

    @Test func multipleDoseTimesCreateExpectedOccurrences() async throws {
        let useCase = makeUseCase()
        let input = try makeAddInput(doseTimes: [(8, 0), (20, 30)])

        let result = try await useCase.execute(
            input: input,
            referenceDate: TestDates.date(2026, 4, 3, 13, 45)
        )

        #expect(result.scheduledDoses.count == 28)
        #expect(result.scheduledDoses.filter { TestDates.calendar.component(.hour, from: $0.scheduledAt) == 8 }.count == 14)
        #expect(result.scheduledDoses.filter { TestDates.calendar.component(.hour, from: $0.scheduledAt) == 20 }.count == 14)
    }

    @Test func addValidationFailureDoesNotSchedule() async throws {
        let medicationRepository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let useCase = makeUseCase(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository
        )
        let input = try makeAddInput(name: "\n ")

        await expectThrows(AddMedicationAndScheduleUseCaseError.medicationCreationFailure(.blankName)) {
            _ = try await useCase.execute(input: input, referenceDate: TestDates.date(2026, 4, 3, 13, 45))
        }

        #expect(medicationRepository.savedMedications.isEmpty)
        #expect(scheduledDoseRepository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func addPersistenceFailureDoesNotSchedule() async throws {
        let medicationRepository = MockMedicationRepository()
        medicationRepository.saveMedicationError = MockMedicationRepositoryError.requestedFailure
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let useCase = makeUseCase(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository
        )
        let input = try makeAddInput()

        await expectThrows(AddMedicationAndScheduleUseCaseError.medicationCreationFailure(.persistenceFailure)) {
            _ = try await useCase.execute(input: input, referenceDate: TestDates.date(2026, 4, 3, 13, 45))
        }

        #expect(scheduledDoseRepository.batchSavedScheduledDoses.isEmpty)
    }

    @Test func scheduleFailureReturnsTypedSchedulingFailureAfterMedicationIsSaved() async throws {
        let medicationRepository = MockMedicationRepository()
        let scheduledDoseRepository = MockScheduledDoseRepository()
        scheduledDoseRepository.saveScheduledDosesError = MockScheduledDoseRepositoryError.requestedFailure
        let useCase = makeUseCase(
            medicationRepository: medicationRepository,
            scheduledDoseRepository: scheduledDoseRepository
        )
        let input = try makeAddInput()

        await expectThrows(AddMedicationAndScheduleUseCaseError.scheduleGenerationFailure(.persistenceFailure)) {
            _ = try await useCase.execute(input: input, referenceDate: TestDates.date(2026, 4, 3, 13, 45))
        }

        #expect(medicationRepository.savedMedications.count == 1)
    }

    @Test func addedMedicationRemainsActive() async throws {
        let useCase = makeUseCase()
        let input = try makeAddInput()

        let result = try await useCase.execute(
            input: input,
            referenceDate: TestDates.date(2026, 4, 3, 13, 45)
        )

        #expect(result.medication.isActive)
    }

    @Test func resultReturnsMedicationAndGeneratedDoses() async throws {
        let scheduledDoseRepository = MockScheduledDoseRepository()
        let useCase = makeUseCase(scheduledDoseRepository: scheduledDoseRepository)
        let input = try makeAddInput()

        let result = try await useCase.execute(
            input: input,
            referenceDate: TestDates.date(2026, 4, 3, 13, 45)
        )

        #expect(result.medication.name == "Vitamin D")
        #expect(result.scheduledDoses == scheduledDoseRepository.batchSavedScheduledDoses.first)
    }

    @Test func rollingWindowIsDeterministicInNonUTCTimeZone() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 10 * 60 * 60)!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let useCase = makeUseCase(calendar: calendar)
        let referenceDate = date(2026, 4, 3, 13, 45, calendar: calendar)
        let input = try makeAddInput(doseTimes: [(8, 15)])

        let result = try await useCase.execute(input: input, referenceDate: referenceDate)
        let firstDose = try #require(result.scheduledDoses.first)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: firstDose.scheduledAt)

        #expect(result.scheduledDoses.count == 14)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 3)
        #expect(components.hour == 8)
        #expect(components.minute == 15)
    }

    private func makeUseCase(
        medicationRepository: MockMedicationRepository = MockMedicationRepository(),
        scheduledDoseRepository: MockScheduledDoseRepository = MockScheduledDoseRepository(),
        calendar: Calendar = TestDates.calendar
    ) -> AddMedicationAndScheduleUseCase {
        let addMedicationUseCase = AddMedicationUseCase(
            medicationRepository: medicationRepository,
            uuidFactory: { UUID(uuidString: "00000000-0000-0000-0000-000000006101")! },
            dateFactory: { TestDates.date(2026, 4, 1, 9, 0) }
        )
        let scheduleMedicationUseCase = ScheduleMedicationUseCase(
            scheduledDoseRepository: scheduledDoseRepository,
            calendar: calendar
        )

        return AddMedicationAndScheduleUseCase(
            addMedicationUseCase: addMedicationUseCase,
            scheduleMedicationUseCase: scheduleMedicationUseCase,
            calendar: calendar
        )
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

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
