import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppStore: ObservableObject {
    @Published var lists: [TaskListModel] = [] { didSet { save() } }
    @Published var tasks: [TaskItem] = [] { didSet { save() } }
    @Published var selection: SidebarSelection = .myDay
    @Published var selectedTaskID: UUID?
    @Published var searchText = ""
    @Published var showingNewList = false
    @Published var showingRecommendations = false
    @Published var alertMessage: String?

    private var hasLoaded = false
    private var shownInAppReminders: Set<UUID> = []

    init() {
        load()
        Self.requestNotificationPermission()
    }

    var selectedTask: TaskItem? {
        guard let id = selectedTaskID else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    var currentTitle: String {
        switch selection {
        case .myDay: "我的一天"
        case .important: "重要"
        case .overdue: "已过期"
        case .completed: "已完成"
        case .list(let id): lists.first(where: { $0.id == id })?.name ?? "列表"
        }
    }

    var visibleTasks: [TaskItem] {
        let base: [TaskItem]
        switch selection {
        case .myDay:
            base = tasks.filter { $0.isInMyDay && !$0.isCompleted }
        case .important:
            base = tasks.filter { $0.isImportant && !$0.isCompleted }
        case .overdue:
            base = tasks.filter { !$0.isCompleted && ($0.dueDate?.isOverdue ?? false) }
        case .completed:
            base = tasks.filter(\.isCompleted)
        case .list(let id):
            base = tasks.filter { $0.listID == id }
        }
        let searched = searchText.isEmpty ? base : base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return sortTasks(searched)
    }

    var recommendations: [TaskItem] {
        let upcoming = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return tasks.filter {
            !$0.isCompleted && !$0.isInMyDay && ($0.isImportant || ($0.dueDate.map { $0 <= upcoming } ?? false))
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func binding(for id: UUID) -> Binding<TaskItem>? {
        guard let initialValue = tasks.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.tasks.first(where: { $0.id == id }) ?? initialValue
            },
            set: { updatedValue in
                guard let currentIndex = self.tasks.firstIndex(where: { $0.id == id }) else { return }
                self.tasks[currentIndex] = updatedValue
            }
        )
    }

    func addTask(title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let listID: UUID
        if case .list(let id) = selection { listID = id }
        else { listID = lists.first?.id ?? addDefaultList() }
        var task = TaskItem(title: clean, listID: listID, order: tasks.count)
        if selection == .myDay { task.myDayKey = Date.todayKey }
        if selection == .important { task.isImportant = true }
        tasks.append(task)
        selectedTaskID = task.id
    }

    @discardableResult
    private func addDefaultList() -> UUID {
        let list = TaskListModel(name: "任务", colorHex: "7C8CFF")
        lists.append(list)
        return list.id
    }

    func addList(name: String, color: String, group: String?) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let list = TaskListModel(name: clean, colorHex: color, group: group?.isEmpty == true ? nil : group, order: lists.count)
        lists.append(list)
        selection = .list(list.id)
    }

    func deleteList(_ id: UUID) {
        guard lists.count > 1 else {
            alertMessage = "至少需要保留一个自定义列表。"
            return
        }
        let fallback = lists.first(where: { $0.id != id })!.id
        for index in tasks.indices where tasks[index].listID == id { tasks[index].listID = fallback }
        lists.removeAll { $0.id == id }
        selection = .list(fallback)
    }

    func toggleCompleted(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = tasks[index].isCompleted
        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
        if !wasCompleted && tasks[index].isCompleted {
            NSSound(named: "Glass")?.play()
            createNextOccurrenceIfNeeded(from: tasks[index])
        }
    }

    func deleteTask(_ id: UUID) {
        if selectedTaskID == id { selectedTaskID = nil }
        tasks.removeAll { $0.id == id }
    }

    func moveTask(_ sourceID: UUID, before targetID: UUID) {
        guard sourceID != targetID,
              let source = tasks.firstIndex(where: { $0.id == sourceID }),
              let target = tasks.firstIndex(where: { $0.id == targetID }) else { return }
        let item = tasks.remove(at: source)
        tasks.insert(item, at: source < target ? max(0, target - 1) : target)
        for index in tasks.indices { tasks[index].order = index }
    }

    func moveList(_ sourceID: UUID, before targetID: UUID) {
        guard sourceID != targetID,
              let source = lists.firstIndex(where: { $0.id == sourceID }),
              let target = lists.firstIndex(where: { $0.id == targetID }) else { return }
        let item = lists.remove(at: source)
        lists.insert(item, at: source < target ? max(0, target - 1) : target)
        for index in lists.indices { lists[index].order = index }
    }

    func checkInAppReminders() {
        guard alertMessage == nil else { return }
        if let task = tasks.first(where: {
            !$0.isCompleted && !shownInAppReminders.contains($0.id) && (($0.reminderDate ?? $0.dueDate).map { $0 <= Date() } ?? false)
        }) {
            shownInAppReminders.insert(task.id)
            alertMessage = "提醒：\(task.title)"
        }
    }

    func addToMyDay(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].myDayKey = Date.todayKey
    }

    func removeFromMyDay(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard !tasks[index].isDueToday else { return }
        tasks[index].myDayKey = nil
    }

    func addStep(taskID: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].steps.append(TaskStep(title: clean))
    }

    func attachFile(to taskID: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard (values?.fileSize ?? 0) <= 25 * 1024 * 1024 else {
            alertMessage = "附件超过 25MB 限制。"
            return
        }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].attachmentPath = url.path
    }

    func exportJSON() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FocusList-备份.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder.pretty.encode(AppSnapshot(lists: lists, tasks: tasks))
            try data.write(to: url, options: .atomic)
        } catch { alertMessage = "导出失败：\(error.localizedDescription)" }
    }

    func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let snapshot = try JSONDecoder.iso8601.decode(AppSnapshot.self, from: Data(contentsOf: url))
            guard !snapshot.lists.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            lists = snapshot.lists
            tasks = normalizedTasks(snapshot.tasks)
            selection = .myDay
        } catch { alertMessage = "导入失败：文件格式不正确。" }
    }

    func scheduleReminder(for task: TaskItem) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        guard let date = task.reminderDate, date > Date(), !task.isCompleted else { return }
        let content = UNMutableNotificationContent()
        content.title = "FocusList 提醒"
        content.body = task.title
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        center.add(UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }

    var currentSort: ListSort {
        if case .list(let id) = selection { return lists.first(where: { $0.id == id })?.sort ?? .dueDate }
        return .dueDate
    }

    func taskGroup(_ task: TaskItem) -> Int {
        switch currentSort {
        case .dueDate: return task.dueDate?.isOverdue == true ? 1 : 0
        case .priority: return task.priority.rawValue
        case .completion: return task.isCompleted ? 1 : 0
        }
    }

    private func sortTasks(_ input: [TaskItem]) -> [TaskItem] {
        return input.sorted { lhs, rhs in
            let leftGroup = taskGroup(lhs), rightGroup = taskGroup(rhs)
            if leftGroup != rightGroup { return leftGroup < rightGroup }
            switch currentSort {
            case .dueDate, .priority:
                if currentSort == .priority && lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                let leftDate = lhs.dueDate ?? .distantFuture
                let rightDate = rhs.dueDate ?? .distantFuture
                if leftDate != rightDate { return leftDate < rightDate }
            case .completion:
                let leftDate = lhs.dueDate ?? .distantPast
                let rightDate = rhs.dueDate ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func createNextOccurrenceIfNeeded(from task: TaskItem) {
        guard task.repeatRule != .none else { return }
        let component: Calendar.Component
        let interval: Int
        switch task.repeatRule {
        case .daily: component = .day; interval = 1
        case .weekly: component = .weekOfYear; interval = 1
        case .biweekly: component = .weekOfYear; interval = 2
        case .monthly: component = .month; interval = 1
        case .none: return
        }
        var next = task
        next.id = UUID()
        next.isCompleted = false
        next.completedAt = nil
        next.createdAt = Date()
        next.steps = next.steps.map { TaskStep(title: $0.title) }
        next.myDayKey = nil
        if let due = task.dueDate { next.dueDate = Calendar.current.date(byAdding: component, value: interval, to: due) }
        if let reminder = task.reminderDate { next.reminderDate = Calendar.current.date(byAdding: component, value: interval, to: reminder) }
        tasks.append(next)
        scheduleReminder(for: next)
    }

    nonisolated private static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private var dataURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("FocusList", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("data.json")
    }

    private func load() {
        defer { hasLoaded = true }
        guard let data = try? Data(contentsOf: dataURL), let snapshot = try? JSONDecoder.iso8601.decode(AppSnapshot.self, from: data) else {
            seed()
            return
        }
        lists = snapshot.lists
        tasks = normalizedTasks(snapshot.tasks)
    }

    private func save() {
        guard hasLoaded else { return }
        let snapshot = AppSnapshot(lists: lists, tasks: tasks)
        guard let data = try? JSONEncoder.pretty.encode(snapshot) else { return }
        try? data.write(to: dataURL, options: .atomic)
    }

    private func normalizedTasks(_ input: [TaskItem]) -> [TaskItem] {
        input.map { task in
            var normalized = task
            if normalized.dueDate == nil { normalized.repeatRule = .none }
            return normalized
        }
    }

    private func seed() {
        let personal = TaskListModel(name: "个人", colorHex: "8B7CFF", isPinned: true, order: 0)
        let work = TaskListModel(name: "工作", colorHex: "41B3A3", group: "项目", order: 1)
        let reading = TaskListModel(name: "阅读清单", colorHex: "E6A15A", group: "个人成长", order: 2)
        lists = [personal, work, reading]
        let calendar = Calendar.current
        tasks = [
            TaskItem(title: "规划今天最重要的三件事", listID: personal.id, dueDate: calendar.date(byAdding: .hour, value: 4, to: Date()), isImportant: true, myDayKey: Date.todayKey, notes: "保持聚焦，先完成最重要的一件。", steps: [TaskStep(title: "整理收件箱", isCompleted: true), TaskStep(title: "确定优先级")], order: 0),
            TaskItem(title: "准备产品评审材料", listID: work.id, dueDate: calendar.date(byAdding: .day, value: 1, to: Date()), myDayKey: Date.todayKey, order: 1),
            TaskItem(title: "阅读《设计中的设计》", listID: reading.id, dueDate: calendar.date(byAdding: .day, value: 3, to: Date()), order: 2)
        ]
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
