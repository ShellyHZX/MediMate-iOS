import Foundation

struct AddMedicationAndScheduleResult: Equatable {
    let medication: Medication
    let scheduledDoses: [ScheduledDose]
}

enum AddMedicationAndScheduleUseCaseError: Error, Equatable {
    case medicationCreationFailure(AddMedicationUseCaseError)
    case invalidSchedulingDateCalculation
    case scheduleGenerationFailure(ScheduleMedicationUseCaseError)
}

struct AddMedicationAndScheduleUseCase {
    private let addMedicationUseCase: AddMedicationUseCase
    private let scheduleMedicationUseCase: ScheduleMedicationUseCase
    private let calendar: Calendar
    private let referenceDateProvider: () -> Date

    init(
        addMedicationUseCase: AddMedicationUseCase,
        scheduleMedicationUseCase: ScheduleMedicationUseCase,
        calendar: Calendar,
        referenceDateProvider: @escaping () -> Date = Date.init
    ) {
        self.addMedicationUseCase = addMedicationUseCase
        self.scheduleMedicationUseCase = scheduleMedicationUseCase
        self.calendar = calendar
        self.referenceDateProvider = referenceDateProvider
    }

    func execute(input: AddMedicationInput) async throws -> AddMedicationAndScheduleResult {
        try await execute(input: input, referenceDate: referenceDateProvider())
    }

    func execute(input: AddMedicationInput, referenceDate: Date) async throws -> AddMedicationAndScheduleResult {
        let medication: Medication

        do {
            medication = try await addMedicationUseCase.execute(input: input)
        } catch let error as AddMedicationUseCaseError {
            throw AddMedicationAndScheduleUseCaseError.medicationCreationFailure(error)
        } catch {
            throw AddMedicationAndScheduleUseCaseError.medicationCreationFailure(.persistenceFailure)
        }

        let startDate = calendar.startOfDay(for: referenceDate)

        guard let endDate = calendar.date(byAdding: .day, value: 14, to: startDate) else {
            throw AddMedicationAndScheduleUseCaseError.invalidSchedulingDateCalculation
        }

        do {
            let scheduledDoses = try await scheduleMedicationUseCase.execute(
                medication: medication,
                startDate: startDate,
                endDate: endDate
            )

            return AddMedicationAndScheduleResult(
                medication: medication,
                scheduledDoses: scheduledDoses
            )
        } catch let error as ScheduleMedicationUseCaseError {
            throw AddMedicationAndScheduleUseCaseError.scheduleGenerationFailure(error)
        } catch {
            throw AddMedicationAndScheduleUseCaseError.scheduleGenerationFailure(.persistenceFailure)
        }
    }
}
