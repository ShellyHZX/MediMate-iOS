import Foundation

enum ScheduleMedicationUseCaseError: Error, Equatable {
    case inactiveMedication
    case invalidDateRange
    case persistenceFailure
}

struct ScheduleMedicationUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository
    private let calendar: Calendar

    init(scheduledDoseRepository: ScheduledDoseRepository, calendar: Calendar) {
        self.scheduledDoseRepository = scheduledDoseRepository
        self.calendar = calendar
    }

    func execute(
        medication: Medication,
        startDate: Date,
        endDate: Date
    ) async throws -> [ScheduledDose] {
        guard medication.isActive else {
            throw ScheduleMedicationUseCaseError.inactiveMedication
        }

        guard startDate < endDate else {
            throw ScheduleMedicationUseCaseError.invalidDateRange
        }

        let scheduledDoses = generateScheduledDoses(
            medication: medication,
            startDate: startDate,
            endDate: endDate
        )

        do {
            try await scheduledDoseRepository.saveScheduledDoses(scheduledDoses)
            return scheduledDoses
        } catch {
            throw ScheduleMedicationUseCaseError.persistenceFailure
        }
    }

    private func generateScheduledDoses(
        medication: Medication,
        startDate: Date,
        endDate: Date
    ) -> [ScheduledDose] {
        var doses: [ScheduledDose] = []
        var scheduledInstants = Set<Date>()
        var day = calendar.startOfDay(for: startDate)

        while day < endDate {
            for doseTime in medication.schedule.dailyDoseTimes {
                guard let scheduledAt = calendar.date(
                    bySettingHour: doseTime.hour,
                    minute: doseTime.minute,
                    second: 0,
                    of: day,
                    matchingPolicy: .strict,
                    repeatedTimePolicy: .first,
                    direction: .forward
                ) else {
                    continue
                }

                guard scheduledAt >= startDate, scheduledAt < endDate else {
                    continue
                }

                guard scheduledInstants.insert(scheduledAt).inserted else {
                    continue
                }

                doses.append(
                    ScheduledDose(
                        medicationID: medication.id,
                        medicationName: medication.name,
                        dosage: medication.dosage,
                        scheduledAt: scheduledAt,
                        status: .upcoming,
                        takenAt: nil
                    )
                )
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            day = nextDay
        }

        return doses.sorted { $0.scheduledAt < $1.scheduledAt }
    }
}
