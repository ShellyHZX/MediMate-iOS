import Foundation

enum ReviewMedicationHistoryUseCaseError: Error, Equatable {
    case invalidDateCalculation
    case persistenceFailure
}

struct ReviewMedicationHistoryUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository
    private let calendar: Calendar

    init(scheduledDoseRepository: ScheduledDoseRepository, calendar: Calendar) {
        self.scheduledDoseRepository = scheduledDoseRepository
        self.calendar = calendar
    }

    func execute(referenceDate: Date) async throws -> [ScheduledDose] {
        guard let historyWindowDate = calendar.date(byAdding: .day, value: -29, to: referenceDate) else {
            throw ReviewMedicationHistoryUseCaseError.invalidDateCalculation
        }

        let historyStart = calendar.startOfDay(for: historyWindowDate)
        let fetchedDoses: [ScheduledDose]

        do {
            fetchedDoses = try await scheduledDoseRepository.fetchScheduledDoses(
                from: historyStart,
                to: referenceDate
            )
        } catch {
            throw ReviewMedicationHistoryUseCaseError.persistenceFailure
        }

        return fetchedDoses.sorted {
            if $0.scheduledAt == $1.scheduledAt {
                return $0.id.uuidString < $1.id.uuidString
            }

            return $0.scheduledAt > $1.scheduledAt
        }
    }
}
