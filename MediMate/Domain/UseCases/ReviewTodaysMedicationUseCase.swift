import Foundation

enum ReviewTodaysMedicationUseCaseError: Error, Equatable {
    case invalidDateCalculation
    case persistenceFailure
}

struct ReviewTodaysMedicationUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository
    private let calendar: Calendar

    init(scheduledDoseRepository: ScheduledDoseRepository, calendar: Calendar) {
        self.scheduledDoseRepository = scheduledDoseRepository
        self.calendar = calendar
    }

    func execute(referenceDate: Date) async throws -> DailyMedicationSummary {
        let startOfDay = calendar.startOfDay(for: referenceDate)

        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw ReviewTodaysMedicationUseCaseError.invalidDateCalculation
        }

        let fetchedDoses: [ScheduledDose]

        do {
            fetchedDoses = try await scheduledDoseRepository.fetchScheduledDoses(
                from: startOfDay,
                to: startOfNextDay
            )
        } catch {
            throw ReviewTodaysMedicationUseCaseError.persistenceFailure
        }

        let doses = fetchedDoses
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .map { deriveDisplayStatus(for: $0, referenceDate: referenceDate) }

        let completedCount = doses.filter { $0.status == .taken }.count
        let priorityDose = doses.first {
            $0.status != .taken && $0.status != .skipped
        }

        return DailyMedicationSummary(
            doses: doses,
            completedCount: completedCount,
            totalCount: doses.count,
            priorityDose: priorityDose
        )
    }

    private func deriveDisplayStatus(
        for scheduledDose: ScheduledDose,
        referenceDate: Date
    ) -> ScheduledDose {
        switch scheduledDose.status {
        case .taken, .skipped:
            return scheduledDose

        case .upcoming, .due, .missed:
            let displayStatus: DoseStatus = scheduledDose.scheduledAt > referenceDate ? .upcoming : .due

            return ScheduledDose(
                id: scheduledDose.id,
                medicationID: scheduledDose.medicationID,
                medicationName: scheduledDose.medicationName,
                dosage: scheduledDose.dosage,
                scheduledAt: scheduledDose.scheduledAt,
                status: displayStatus,
                takenAt: scheduledDose.takenAt
            )
        }
    }
}
