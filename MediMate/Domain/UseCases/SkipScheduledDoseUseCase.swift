import Foundation

enum SkipScheduledDoseUseCaseError: Error, Equatable {
    case doseNotFound
    case doseAlreadyTaken
    case doseAlreadySkipped
    case persistenceFailure
}

struct SkipScheduledDoseUseCase {
    private let scheduledDoseRepository: ScheduledDoseRepository

    init(scheduledDoseRepository: ScheduledDoseRepository) {
        self.scheduledDoseRepository = scheduledDoseRepository
    }

    func execute(scheduledDoseID: UUID) async throws -> ScheduledDose {
        let scheduledDose: ScheduledDose

        do {
            guard let fetchedDose = try await scheduledDoseRepository.fetchScheduledDose(id: scheduledDoseID) else {
                throw SkipScheduledDoseUseCaseError.doseNotFound
            }

            scheduledDose = fetchedDose
        } catch let error as SkipScheduledDoseUseCaseError {
            throw error
        } catch {
            throw SkipScheduledDoseUseCaseError.persistenceFailure
        }

        switch scheduledDose.status {
        case .upcoming, .due, .missed:
            let updatedDose = ScheduledDose(
                id: scheduledDose.id,
                medicationID: scheduledDose.medicationID,
                medicationName: scheduledDose.medicationName,
                dosage: scheduledDose.dosage,
                scheduledAt: scheduledDose.scheduledAt,
                status: .skipped,
                takenAt: nil
            )

            do {
                try await scheduledDoseRepository.saveScheduledDose(updatedDose)
                return updatedDose
            } catch {
                throw SkipScheduledDoseUseCaseError.persistenceFailure
            }

        case .taken:
            throw SkipScheduledDoseUseCaseError.doseAlreadyTaken

        case .skipped:
            throw SkipScheduledDoseUseCaseError.doseAlreadySkipped
        }
    }
}
