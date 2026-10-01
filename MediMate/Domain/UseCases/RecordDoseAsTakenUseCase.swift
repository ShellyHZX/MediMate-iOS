import Foundation

enum RecordDoseAsTakenUseCaseError: Error, Equatable {
    case doseNotFound
    case alreadyTaken
    case doseWasSkipped
    case persistenceFailure
}

struct RecordDoseAsTakenUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository

    init(scheduledDoseRepository: ScheduledDoseRepository) {
        self.scheduledDoseRepository = scheduledDoseRepository
    }

    func execute(scheduledDoseID: UUID, takenAt: Date) async throws -> ScheduledDose {
        let scheduledDose: ScheduledDose

        do {
            guard let fetchedDose = try await scheduledDoseRepository.fetchScheduledDose(id: scheduledDoseID) else {
                throw RecordDoseAsTakenUseCaseError.doseNotFound
            }

            scheduledDose = fetchedDose
        } catch let error as RecordDoseAsTakenUseCaseError {
            throw error
        } catch {
            throw RecordDoseAsTakenUseCaseError.persistenceFailure
        }

        switch scheduledDose.status {
        case .upcoming, .due, .missed:
            let updatedDose = ScheduledDose(
                id: scheduledDose.id,
                medicationID: scheduledDose.medicationID,
                medicationName: scheduledDose.medicationName,
                dosage: scheduledDose.dosage,
                scheduledAt: scheduledDose.scheduledAt,
                status: .taken,
                takenAt: takenAt
            )

            do {
                try await scheduledDoseRepository.saveScheduledDose(updatedDose)
                return updatedDose
            } catch {
                throw RecordDoseAsTakenUseCaseError.persistenceFailure
            }

        case .taken:
            throw RecordDoseAsTakenUseCaseError.alreadyTaken

        case .skipped:
            throw RecordDoseAsTakenUseCaseError.doseWasSkipped
        }
    }
}
