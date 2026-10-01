import Foundation
import Testing
@testable import MediMate

enum TestDates {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}

func makeScheduledDose(
    id: UUID = UUID(),
    medicationID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
    medicationName: String = "Vitamin D",
    dosage: Dosage? = Dosage(amount: 1, unit: .tablet),
    scheduledAt: Date = TestDates.date(2026, 1, 10, 8, 0),
    status: DoseStatus,
    takenAt: Date? = nil
) throws -> ScheduledDose {
    ScheduledDose(
        id: id,
        medicationID: medicationID,
        medicationName: medicationName,
        dosage: try #require(dosage),
        scheduledAt: scheduledAt,
        status: status,
        takenAt: takenAt
    )
}

func expectThrows<E: Error & Equatable>(
    _ expectedError: E,
    operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected \(expectedError) to be thrown.")
    } catch let error as E {
        #expect(error == expectedError)
    } catch {
        Issue.record("Expected \(expectedError), but received \(error).")
    }
}
