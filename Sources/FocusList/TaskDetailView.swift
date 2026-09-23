import AppKit
import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Group {
            if let id = store.selectedTaskID, let binding = store.binding(for: id) {
                DetailForm(store: store, task: binding)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.right").font(.system(size: 25, weight: .light)).foregroundStyle(Theme.secondary)
                    Text("选择任务查看详情").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(Theme.panel).foregroundStyle(Theme.primary)
    }
}

private struct DetailForm: View {
    @ObservedObject var store: AppStore
    @Binding var task: TaskItem
    @State private var stepText = ""
    @State private var showingDueDatePicker = false
    @State private var showingReminderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("任务详情").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { store.selectedTaskID = nil } label: { Image(systemName: "xmark").foregroundStyle(Theme.secondary) }.buttonStyle(IconButtonStyle())
            }.padding(.horizontal, 16).frame(height: 52).overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("任务名称", text: $task.title, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 17, weight: .semibold)).lineLimit(1...4)

                    section("状态") {
                        HStack {
                            Label("分组", systemImage: "folder").frame(width: 78, alignment: .leading)
                            Picker("", selection: $task.listID) {
                                ForEach(availableLists) { list in
                                    Text(list.name).tag(list.id)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                        Picker("优先级", selection: $task.priority) {
                            ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                        }
                        detailToggle(icon: "star", title: "重要", isOn: $task.isImportant)
                        detailToggle(icon: "sun.max", title: "我的一天", isOn: Binding(get: { task.isInMyDay }, set: { if !task.isDueToday { task.myDayKey = $0 ? Date.todayKey : nil } }))
                            .disabled(task.isDueToday)
                            .help(task.isDueToday ? "今天截止的任务自动加入我的一天" : "添加到我的一天")
                    }

                    section("时间") {
                        optionalDateRow(icon: "calendar", title: "截止日期", value: $task.dueDate, isPresented: $showingDueDatePicker)
                        optionalDateRow(icon: "bell", title: "提醒", value: $task.reminderDate, includesTime: true, isPresented: $showingReminderPicker)
                        if task.dueDate != nil {
                            HStack {
                                Label("重复", systemImage: "repeat").frame(width: 78, alignment: .leading)
                                Picker("", selection: $task.repeatRule) { ForEach(RepeatRule.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
                            }
                        }
                    }

                    section("子步骤") {
                        ForEach(task.steps) { step in
                            HStack {
                                Button { toggleStep(step.id) } label: { Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle").foregroundStyle(step.isCompleted ? Color(hex: "70C994") : Theme.secondary) }.buttonStyle(.plain)
                                TextField("子步骤", text: stepTitleBinding(for: step)).textFieldStyle(.plain).strikethrough(step.isCompleted)
                                Button { task.steps.removeAll { $0.id == step.id } } label: { Image(systemName: "xmark").foregroundStyle(Theme.secondary) }.buttonStyle(.plain)
                            }.padding(.vertical, 4)
                        }
                        HStack {
                            Image(systemName: "plus").foregroundStyle(Theme.secondary)
                            TextField("添加子步骤", text: $stepText).textFieldStyle(.plain).onSubmit { store.addStep(taskID: task.id, title: stepText); stepText = "" }
                        }.padding(.vertical, 5)
                    }

                    section("备注") {
                        TextEditor(text: $task.notes).font(.system(size: 12)).scrollContentBackground(.hidden)
                            .frame(minHeight: 92).padding(8).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 7))
                    }

                    section("附件") {
                        if let path = task.attachmentPath {
                            HStack {
                                Image(systemName: "doc")
                                Button(URL(fileURLWithPath: path).lastPathComponent) { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }.buttonStyle(.plain).lineLimit(1)
                                Spacer()
                                Button { task.attachmentPath = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                            }.foregroundStyle(Theme.secondary)
                        }
                        Button { store.attachFile(to: task.id) } label: { Label("选择本机文件", systemImage: "paperclip") }.buttonStyle(.bordered)
                    }
                }.padding(18)
            }

            HStack {
                Text(task.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(Theme.secondary)
                Spacer()
                Button(role: .destructive) { store.deleteTask(task.id) } label: { Image(systemName: "trash") }.buttonStyle(IconButtonStyle())
            }.padding(.horizontal, 16).frame(height: 45).overlay(Rectangle().fill(Theme.line).frame(height: 1), alignment: .top)
        }
        .onChange(of: task.reminderDate) { _, _ in store.scheduleReminder(for: task) }
        .onChange(of: task.dueDate) { _, newDate in
            if newDate == nil { task.repeatRule = .none }
            store.scheduleReminder(for: task)
        }
    }

    private var availableLists: [TaskListModel] {
        store.lists
            .filter { !$0.isHidden || $0.id == task.listID }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.order < $1.order
            }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(Theme.secondary)
            VStack(alignment: .leading, spacing: 9, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11).background(Theme.elevated).clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: icon)
            Spacer(minLength: 16)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .frame(maxWidth: .infinity)
    }

    private func stepTitleBinding(for step: TaskStep) -> Binding<String> {
        Binding(
            get: { task.steps.first(where: { $0.id == step.id })?.title ?? step.title },
            set: { newTitle in
                guard let index = task.steps.firstIndex(where: { $0.id == step.id }) else { return }
                task.steps[index].title = newTitle
            }
        )
    }

    private func toggleStep(_ id: UUID) {
        guard let index = task.steps.firstIndex(where: { $0.id == id }) else { return }
        task.steps[index].isCompleted.toggle()
    }

    private func optionalDateRow(icon: String, title: String, value: Binding<Date?>, includesTime: Bool = false, isPresented: Binding<Bool>) -> some View {
        HStack {
            Label(title, systemImage: icon).frame(width: 78, alignment: .leading)
            Spacer()
            if let date = value.wrappedValue {
                Button {
                    isPresented.wrappedValue = true
                } label: {
                    Text(includesTime ? date.formatted(date: .numeric, time: .shortened) : date.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: isPresented, arrowEdge: .trailing) {
                    LargeDatePickerPopover(
                        date: Binding(get: { value.wrappedValue ?? Date() }, set: { value.wrappedValue = $0 }),
                        includesTime: includesTime,
                        clear: { value.wrappedValue = nil; isPresented.wrappedValue = false },
                        done: { isPresented.wrappedValue = false }
                    )
                }
                if includesTime {
                    Button {
                        isPresented.wrappedValue = false
                        value.wrappedValue = nil
                        store.scheduleReminder(for: task)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.secondary)
                    .help("取消提醒")
                    .accessibilityLabel("取消提醒")
                }
            } else {
                Button("设置") {
                    value.wrappedValue = includesTime ? Date().addingTimeInterval(3600) : Date()
                    isPresented.wrappedValue = true
                }
                .buttonStyle(.plain).foregroundStyle(Theme.purple)
                .popover(isPresented: isPresented, arrowEdge: .trailing) {
                    LargeDatePickerPopover(
                        date: Binding(get: { value.wrappedValue ?? Date() }, set: { value.wrappedValue = $0 }),
                        includesTime: includesTime,
                        clear: { value.wrappedValue = nil; isPresented.wrappedValue = false },
                        done: { isPresented.wrappedValue = false }
                    )
                }
            }
        }
    }
}

private struct LargeDatePickerPopover: View {
    @Binding var date: Date
    let includesTime: Bool
    let clear: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            DatePicker("选择日期", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .controlSize(.large)
                .fixedSize()
                .scaleEffect(1.5)
                .frame(width: 240, height: 235)

            if includesTime {
                Divider()
                HStack {
                    Label("提醒时间", systemImage: "clock")
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                        .labelsHidden().controlSize(.large)
                }
            }

        }
        .frame(width: 240)
        .preferredColorScheme(.dark)
    }
}
