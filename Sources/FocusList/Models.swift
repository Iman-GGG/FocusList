import Foundation

enum ListSort: String, Codable, CaseIterable, Identifiable {
    case dueDate = "截止日期"
    case completion = "完成状态"
    case priority = "优先级"
    var id: String { rawValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "手动排序" { self = .dueDate; return }
        if value == "创建时间" { self = .completion; return }
        guard let sort = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown list sort")
        }
        self = sort
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none = "不重复"
    case daily = "每天"
    case weekly = "每周"
    case biweekly = "每两周"
    case monthly = "每月"
    var id: String { rawValue }
}

struct TaskStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var isCompleted = false
}

enum TaskPriority: Int, Codable, CaseIterable, Identifiable {
    case p0 = 0, p1 = 1, p2 = 2
    var id: Int { rawValue }
    var title: String { "P\(rawValue)" }
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var listID: UUID
    var createdAt = Date()
    var isCompleted = false
    var completedAt: Date?
    var dueDate: Date?
    var reminderDate: Date?
    var repeatRule: RepeatRule = .none
    var isImportant = false
    var priorityValue: TaskPriority?
    var priority: TaskPriority {
        get { priorityValue ?? .p2 }
        set { priorityValue = newValue }
    }
    var myDayKey: String?
    var notes = ""
    var attachmentPath: String?
    var steps: [TaskStep] = []
    var order = 0
    var isDueToday: Bool { dueDate?.isTodayLocal ?? false }
    var isInMyDay: Bool { isDueToday || myDayKey == Date.todayKey }
}

struct TaskListModel: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    var group: String?
    var isPinned = false
    var isHidden = false
    var sort: ListSort = .dueDate
    var order = 0
    var createdAt = Date()
}

struct AppSnapshot: Codable {
    var lists: [TaskListModel]
    var tasks: [TaskItem]
}

enum SidebarSelection: Hashable {
    case myDay, important, overdue, completed, list(UUID)
}

extension Date {
    static var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var isTodayLocal: Bool { Calendar.current.isDateInToday(self) }
    var isOverdue: Bool { self < Date() && !isTodayLocal }
}
