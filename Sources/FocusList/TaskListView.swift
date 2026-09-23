import SwiftUI

struct TaskListView: View {
    @ObservedObject var store: AppStore
    @State private var newTask = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.visibleTasks.isEmpty { emptyState } else { taskList }
            quickAdd
        }
        .background(Theme.background)
        .foregroundStyle(Theme.primary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.currentTitle).font(.system(size: 26, weight: .bold))
                    if store.selection == .myDay {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.system(size: 12)).foregroundStyle(Theme.secondary)
                    }
                }
                Spacer()
                if case .list(let id) = store.selection, store.lists.contains(where: { $0.id == id }) {
                    Picker("排序", selection: Binding(
                        get: { store.lists.first(where: { $0.id == id })?.sort ?? .dueDate },
                        set: { newSort in
                            guard let currentIndex = store.lists.firstIndex(where: { $0.id == id }) else { return }
                            store.lists[currentIndex].sort = newSort
                        }
                    )) {
                        ForEach(ListSort.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 120)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondary)
                TextField("搜索当前视图", text: $store.searchText).textFieldStyle(.plain).font(.system(size: 12))
            }
            .padding(.horizontal, 10).frame(height: 32).background(Theme.elevated).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 16)
        .overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .bottom)
    }

    private var taskList: some View {
        let tasks = store.visibleTasks
        return ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 && store.taskGroup(tasks[index - 1]) != store.taskGroup(task) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.16))
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    TaskRow(store: store, task: task)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.04)).frame(width: 74, height: 74)
                Image(systemName: store.selection == .completed ? "checkmark.circle" : "tray")
                    .font(.system(size: 29, weight: .light)).foregroundStyle(Theme.secondary)
            }
            Text(store.searchText.isEmpty ? "这里很安静" : "没有匹配的任务").font(.system(size: 15, weight: .semibold))
            Text(store.searchText.isEmpty ? "在下方添加一项，开始专注。" : "换一个关键词试试。")
                .font(.system(size: 12)).foregroundStyle(Theme.secondary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var quickAdd: some View {
        HStack(spacing: 10) {
            TextField("添加任务", text: $newTask)
                .textFieldStyle(.plain).font(.system(size: 13))
                .onSubmit { store.addTask(title: newTask); newTask = "" }
            Text("↵").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.secondary)
                .padding(.horizontal, 7).padding(.vertical, 4).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 14).frame(height: 46).background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(16).overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .top)
    }
}

struct TaskRow: View {
    @ObservedObject var store: AppStore
    let task: TaskItem
    @State private var hovering = false

    var body: some View {
        Button { store.selectedTaskID = task.id } label: {
            HStack(alignment: .top, spacing: 11) {
                Button { store.toggleCompleted(task.id) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17)).foregroundStyle(task.isCompleted ? Color(hex: "70C994") : Theme.secondary)
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(task.isCompleted).foregroundStyle(task.isCompleted ? Theme.secondary : Theme.primary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(task.priority.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(task.priority == .p0 ? Color(hex: "FF756B") : task.priority == .p1 ? Color(hex: "FFC857") : Theme.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        if let due = task.dueDate {
                            Pill(icon: "calendar", text: due.isTodayLocal ? "今天" : due.formatted(date: .abbreviated, time: .omitted), color: due.isOverdue && !task.isCompleted ? Color(hex: "FF756B") : Theme.secondary)
                            if task.repeatRule != .none {
                                Pill(icon: "repeat", text: task.repeatRule.rawValue)
                            }
                        }
                        if !task.steps.isEmpty {
                            Pill(icon: "checklist", text: "\(task.steps.filter(\.isCompleted).count)/\(task.steps.count)")
                        }
                        if task.attachmentPath != nil { Image(systemName: "paperclip").font(.system(size: 10)).foregroundStyle(Theme.secondary) }
                    }
                }
                Spacer()
                Button {
                    guard let index = store.tasks.firstIndex(where: { $0.id == task.id }) else { return }
                    store.tasks[index].isImportant.toggle()
                } label: {
                    Image(systemName: task.isImportant ? "star.fill" : "star")
                        .foregroundStyle(task.isImportant ? Color(hex: "FFC857") : Theme.secondary.opacity(hovering ? 1 : 0.45))
                }.buttonStyle(IconButtonStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(store.selectedTaskID == task.id ? Color.white.opacity(0.085) : (hovering ? Color.white.opacity(0.04) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).onHover { hovering = $0 }
        .contextMenu {
            if task.isInMyDay { Button("从我的一天移除") { store.removeFromMyDay(task.id) }.disabled(task.isDueToday) }
            else { Button("添加到我的一天") { store.addToMyDay(task.id) } }
            Divider()
            Button("删除任务", role: .destructive) { store.deleteTask(task.id) }
        }
    }
}

struct RecommendationsSheet: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "sparkles").foregroundStyle(Theme.accent); Text("建议添加到我的一天").font(.system(size: 19, weight: .semibold)); Spacer(); Button("完成") { dismiss() } }
            if store.recommendations.isEmpty {
                Text("暂无临近截止或星标任务。").foregroundStyle(Theme.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(store.recommendations) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) { Text(task.title); if let due = task.dueDate { Text(due.formatted()).font(.caption).foregroundStyle(Theme.secondary) } }
                                Spacer()
                                Button("添加") { store.addToMyDay(task.id) }.buttonStyle(.borderedProminent).tint(Theme.purple)
                            }.padding(10).background(Theme.elevated).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }.padding(22).frame(width: 440, height: 360).background(Theme.panel).preferredColorScheme(.dark)
    }
}
