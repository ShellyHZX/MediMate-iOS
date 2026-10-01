import Foundation
@testable import MediMate

enum MockScheduledDoseRepositoryError: Error {
    case requestedFailure
}

final class MockScheduledDoseRepository: ScheduledDoseRepository {
    var scheduledDoseByID: [UUID: ScheduledDose] = [:]
    var scheduledDosesInRange: [ScheduledDose] = []

    var fetchScheduledDoseError: Error?
    var fetchScheduledDosesError: Error?
    var saveScheduledDoseError: Error?
    var saveScheduledDosesError: Error?

    private(set) var fetchedScheduledDoseIDs: [UUID] = []
    private(set) var fetchedRangeRequests: [(startDate: Date, endDate: Date)] = []
    private(set) var savedScheduledDoses: [ScheduledDose] = []
    private(set) var batchSavedScheduledDoses: [[ScheduledDose]] = []

    func fetchScheduledDose(id: UUID) async throws -> ScheduledDose? {
        fetchedScheduledDoseIDs.append(id)

        if let fetchScheduledDoseError {
            throw fetchScheduledDoseError
        }

        return scheduledDoseByID[id]
    }

    func fetchScheduledDoses(from startDate: Date, to endDate: Date) async throws -> [ScheduledDose] {
        fetchedRangeRequests.append((startDate, endDate))

        if let fetchScheduledDosesError {
            throw fetchScheduledDosesError
        }

        return scheduledDosesInRange
    }

    func saveScheduledDose(_ scheduledDose: ScheduledDose) async throws {
        if let saveScheduledDoseError {
            throw saveScheduledDoseError
        }

        savedScheduledDoses.append(scheduledDose)
    }

    func saveScheduledDoses(_ scheduledDoses: [ScheduledDose]) async throws {
        if let saveScheduledDosesError {
            throw saveScheduledDosesError
        }

        batchSavedScheduledDoses.append(scheduledDoses)
    }
}
