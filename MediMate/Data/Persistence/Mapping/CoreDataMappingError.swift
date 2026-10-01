import Foundation

enum CoreDataMappingError: Error, Equatable {
    case missingRequiredValue(entity: String, field: String)
    case invalidDosage
    case invalidDosageUnit(String)
    case invalidDoseTime(hour: Int, minute: Int)
    case invalidDoseSchedule
    case invalidDoseStatus(String)
}
