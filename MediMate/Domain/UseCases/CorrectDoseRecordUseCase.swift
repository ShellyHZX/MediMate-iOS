import Foundation

enum DoseRecordCorrection: Equatable {
    case taken(at: Date)
    case skipped
    case notTaken
}

enum CorrectDoseRecordUseCaseError: Error, Equatable {
    case doseNotFound
    case persistenceFailure
}

struct CorrectDoseRecordUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository
    private let calendar: Calendar

    init(scheduledDoseRepository: ScheduledDoseRepository, calendar: Calendar) {
        self.scheduledDoseRepository = scheduledDoseRepository
        self.calendar = calendar
    }

    func execute(
        scheduledDoseID: UUID,
        correction: DoseRecordCorrection,
        referenceDate: Date
    ) async throws -> ScheduledDose {
        let scheduledDose: ScheduledDose

        do {
            guard let fetchedDose = try await scheduledDoseRepository.fetchScheduledDose(id: scheduledDoseID) else {
                throw CorrectDoseRecordUseCaseError.doseNotFound
            }

            scheduledDose = fetchedDose
        } catch let error as CorrectDoseRecordUseCaseError {
            throw error
        } catch {
            throw CorrectDoseRecordUseCaseError.persistenceFailure
        }

        let correctedDose = correctedScheduledDose(
            scheduledDose,
            correction: correction,
            referenceDate: referenceDate
        )

        do {
            try await scheduledDoseRepository.saveScheduledDose(correctedDose)
            return correctedDose
        } catch {
            throw CorrectDoseRecordUseCaseError.persistenceFailure
        }
    }

    private func correctedScheduledDose(
        _ scheduledDose: ScheduledDose,
        correction: DoseRecordCorrection,
        referenceDate: Date
    ) -> ScheduledDose {
        let status: DoseStatus
        let takenAt: Date?

        switch correction {
        case .taken(let date):
            status = .taken
            takenAt = date

        case .skipped:
            status = .skipped
            takenAt = nil

        case .notTaken:
            status = unresolvedStatus(for: scheduledDose.scheduledAt, referenceDate: referenceDate)
            takenAt = nil
        }

        return ScheduledDose(
            id: scheduledDose.id,
            medicationID: scheduledDose.medicationID,
            medicationName: scheduledDose.medicationName,
            dosage: scheduledDose.dosage,
            scheduledAt: scheduledDose.scheduledAt,
            status: status,
            takenAt: takenAt
        )
    }

    private func unresolvedStatus(for scheduledAt: Date, referenceDate: Date) -> DoseStatus {
        if scheduledAt > referenceDate {
            return .upcoming
        }

        if calendar.isDate(scheduledAt, inSameDayAs: referenceDate) {
            return .due
        }

        return .missed
    }
}
