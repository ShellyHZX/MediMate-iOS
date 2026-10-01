import Foundation

extension DoseStatus {
    var persistedRawValue: String {
        switch self {
        case .upcoming:
            return "upcoming"
        case .due:
            return "due"
        case .taken:
            return "taken"
        case .skipped:
            return "skipped"
        case .missed:
            return "missed"
        }
    }

    init(persistedRawValue: String) throws {
        switch persistedRawValue {
        case "upcoming":
            self = .upcoming
        case "due":
            self = .due
        case "taken":
            self = .taken
        case "skipped":
            self = .skipped
        case "missed":
            self = .missed
        default:
            throw CoreDataMappingError.invalidDoseStatus(persistedRawValue)
        }
    }
}
