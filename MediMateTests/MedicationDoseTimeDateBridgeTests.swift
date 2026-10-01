import Foundation
import Testing
@testable import MediMate

struct MedicationDoseTimeDateBridgeTests {
    @Test func dateFromDoseTimePreservesHourAndMinute() throws {
        let calendar = TestDates.calendar
        let doseTime = try #require(DoseTime(hour: 20, minute: 45))

        let date = MedicationDoseTimeDateBridge.date(from: doseTime, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: date)

        #expect(components.hour == 20)
        #expect(components.minute == 45)
    }

    @Test func doseTimeFromDatePreservesHourAndMinute() throws {
        let calendar = TestDates.calendar
        let date = TestDates.date(2026, 1, 1, 7, 15)

        let doseTime = try #require(MedicationDoseTimeDateBridge.doseTime(from: date, calendar: calendar))
        let expectedDoseTime = try #require(DoseTime(hour: 7, minute: 15))

        #expect(doseTime == expectedDoseTime)
    }
}
