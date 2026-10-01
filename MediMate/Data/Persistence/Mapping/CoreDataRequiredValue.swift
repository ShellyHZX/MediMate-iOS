import Foundation

func required<T>(_ value: T?, entity: String, field: String) throws -> T {
    guard let value else {
        throw CoreDataMappingError.missingRequiredValue(entity: entity, field: field)
    }

    return value
}
