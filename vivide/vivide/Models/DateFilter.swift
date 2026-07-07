import Foundation

enum DateFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case today = "今天"
    case thisWeek = "本周"
    case thisMonth = "本月"
    case thisYear = "今年"
    case custom = "自定义"

    var id: String { rawValue }

    func contains(_ date: Date?, customStart: Date, customEnd: Date) -> Bool {
        guard let date else { return self == .all }
        let calendar = Calendar.current

        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .thisWeek:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .thisYear:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .year)
        case .custom:
            let start = calendar.startOfDay(for: customStart)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
            return date >= start && date <= end
        }
    }
}
