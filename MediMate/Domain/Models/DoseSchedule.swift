import Foundation

struct DoseSchedule: Equatable {
    let dailyDoseTimes: [DoseTime]

    init?(dailyDoseTimes: [DoseTime]) {
        guard !dailyDoseTimes.isEmpty else {
            return nil
        }

        guard Set(dailyDoseTimes).count == dailyDoseTimes.count else {
            return nil
        }

        self.dailyDoseTimes = dailyDoseTimes.sorted {
            ($0.hour, $0.minute) < ($1.hour, $1.minute)
        }
    }
}
