import Foundation

struct DoseTime: Equatable, Hashable {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }

        self.hour = hour
        self.minute = minute
    }
}
