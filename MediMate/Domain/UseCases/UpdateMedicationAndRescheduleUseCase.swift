import Foundation

struct UpdateMedicationAndRescheduleResult: Equatable {
    let medication: Medication
    let scheduledDoses: [ScheduledDose]
}

enum UpdateMedicationAndRescheduleUseCaseError: Error, Equatable {
    case medicationUpdateFailure(UpdateMedicationUseCaseError)
    case invalidSchedulingDateCalculation
    case fetchScheduledDosesFailure
    case deleteScheduledDosesFailure
    case scheduleGenerationFailure(ScheduleMedicationUseCaseError)
}

struct UpdateMedicationAndRescheduleUseCase {
    private let updateMedicationUseCase: UpdateMedicationUseCase
    private let scheduleMedicationUseCase: ScheduleMedicationUseCase
    private let scheduledDoseRepository: ScheduledDoseRepository
    private let calendar: Calendar
    private let referenceDateProvider: () -> Date

    init(
        updateMedicationUseCase: UpdateMedicationUseCase,
        scheduleMedicationUseCase: ScheduleMedicationUseCase,
        scheduledDoseRepository: ScheduledDoseRepository,
        calendar: Calendar,
        referenceDateProvider: @escaping () -> Date = Date.init
    ) {
        self.updateMedicationUseCase = updateMedicationUseCase
        self.scheduleMedicationUseCase = scheduleMedicationUseCase
        self.scheduledDoseRepository = scheduledDoseRepository
        self.calendar = calendar
        self.referenceDateProvider = referenceDateProvider
    }

    func execute(input: UpdateMedicationInput) async throws -> UpdateMedicationAndRescheduleResult {
        try await execute(input: input, referenceDate: referenceDateProvider())
    }

    func execute(input: UpdateMedicationInput, referenceDate: Date) async throws -> UpdateMedicationAndRescheduleResult {
        let medication: Medication

        do {
            medication = try await updateMedicationUseCase.execute(input: input)
        } catch let error as UpdateMedicationUseCaseError {
            throw UpdateMedicationAndRescheduleUseCaseError.medicationUpdateFailure(error)
        } catch {
            throw UpdateMedicationAndRescheduleUseCaseError.medicationUpdateFailure(.persistenceFailure)
        }

        let horizonStart = calendar.startOfDay(for: referenceDate)

        guard let horizonEnd = calendar.date(byAdding: .day, value: 14, to: horizonStart) else {
            throw UpdateMedicationAndRescheduleUseCaseError.invalidSchedulingDateCalculation
        }

        let existingDoses: [ScheduledDose]

        do {
            existingDoses = try await scheduledDoseRepository.fetchScheduledDoses(
                from: horizonStart,
                to: horizonEnd
            )
        } catch {
            throw UpdateMedicationAndRescheduleUseCaseError.fetchScheduledDosesFailure
        }

        let medicationDoses = existingDoses.filter { $0.medicationID == medication.id }
        let finalizedDoses = medicationDoses.filter { $0.status == .taken || $0.status == .skipped }
        let unresolvedDoseIDs = medicationDoses
            .filter { $0.status == .upcoming || $0.status == .due || $0.status == .missed }
            .map(\.id)

        do {
            try await scheduledDoseRepository.deleteScheduledDoses(ids: unresolvedDoseIDs)
        } catch {
            throw UpdateMedicationAndRescheduleUseCaseError.deleteScheduledDosesFailure
        }

        do {
            let scheduledDoses = try await scheduleMedicationUseCase.execute(
                medication: medication,
                startDate: horizonStart,
                endDate: horizonEnd,
                excludingScheduledInstants: Set(finalizedDoses.map(\.scheduledAt))
            )

            return UpdateMedicationAndRescheduleResult(
                medication: medication,
                scheduledDoses: scheduledDoses
            )
        } catch let error as ScheduleMedicationUseCaseError {
            throw UpdateMedicationAndRescheduleUseCaseError.scheduleGenerationFailure(error)
        } catch {
            throw UpdateMedicationAndRescheduleUseCaseError.scheduleGenerationFailure(.persistenceFailure)
        }
    }
}
