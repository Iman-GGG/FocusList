import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: AppStore
    @State private var hovered: SidebarSelection?
    @State private var editingListID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: Bundle.main.url(forResource: "AppIconSource", withExtension: "png").flatMap { NSImage(contentsOf: $0) } ?? NSImage())
                    .resizable().scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text("FocusList").font(.system(size: 14, weight: .semibold))
                    Text("仅存储在这台 Mac").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Menu {
                    Button("导入 JSON…", action: store.importJSON)
                    Button("导出备份…", action: store.exportJSON)
                    if store.lists.contains(where: \.isHidden) {
                        Divider()
                        Menu("已隐藏列表") {
                            ForEach(store.lists.filter(\.isHidden)) { list in
                                Button("显示 \(list.name)") { updateList(list.id) { $0.isHidden = false } }
                            }
                        }
                    }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.secondary) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24)
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 15)

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    systemRow(.myDay, "我的一天", "sun.max", Color(hex: "FFFF45"), count: myDayCount)
                    systemRow(.important, "重要", "star", Color(hex: "F88CD0"), count: store.tasks.filter { $0.isImportant && !$0.isCompleted }.count)
                    systemRow(.overdue, "已过期", "clock.badge.exclamationmark", Color(hex: "FF481F"), count: store.tasks.filter { !$0.isCompleted && ($0.dueDate?.isOverdue ?? false) }.count)
                    systemRow(.completed, "已完成", "checkmark.circle", Color(hex: "19D15B"), count: store.tasks.filter(\.isCompleted).count)

                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 20)
                        Spacer()
                        Button { store.showingNewList = true } label: { Image(systemName: "plus").font(.system(size: 11, weight: .semibold)) }
                            .buttonStyle(IconButtonStyle()).foregroundStyle(Theme.secondary)
                    }
                    .padding(.leading, 10).padding(.top, 20).padding(.trailing, 1)

                    ForEach(groupNames, id: \.self) { group in
                        if let group {
                            Text(group.uppercased())
                                .font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(Theme.secondary.opacity(0.7))
                                .padding(.leading, 10).padding(.top, 10).padding(.bottom, 3)
                        }
                        ForEach(store.lists.filter { $0.group == group && !$0.isHidden }) { list in
                            listRow(list)
                        }
                    }
                }.padding(.horizontal, 8).padding(.bottom, 20)
            }

        }
        .foregroundStyle(Theme.primary)
        .background(Theme.sidebar)
        .sheet(isPresented: $store.showingNewList) { NewListSheet(store: store) }
        .sheet(isPresented: Binding(get: { editingListID != nil }, set: { if !$0 { editingListID = nil } })) {
            if let id = editingListID { EditListSheet(store: store, listID: id) }
        }
    }

    private var myDayCount: Int { store.tasks.filter { $0.isInMyDay && !$0.isCompleted }.count }
    private var groupNames: [String?] {
        var result: [String?] = [nil]
        for group in store.lists.compactMap(\.group) where !result.contains(group) { result.append(group) }
        return result
    }

    private func systemRow(_ selection: SidebarSelection, _ title: String, _ icon: String, _ color: Color, count: Int) -> some View {
        sidebarRow(selection: selection) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium)).foregroundStyle(color).frame(width: 20)
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            if count > 0 { Text("\(count)").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.secondary) }
        }
    }

    private func listRow(_ list: TaskListModel) -> some View {
        sidebarRow(selection: .list(list.id)) {
            Circle().fill(Color(hex: list.colorHex)).frame(width: 8, height: 8).frame(width: 20)
            Text(list.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Spacer()
            Text("\(store.tasks.filter { $0.listID == list.id && !$0.isCompleted }.count)")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.secondary)
        }
        .contextMenu {
            Button("编辑列表…") { editingListID = list.id }
            Button(list.isPinned ? "取消置顶" : "置顶") { updateList(list.id) { $0.isPinned.toggle() } }
            Button("隐藏") { updateList(list.id) { $0.isHidden = true } }
            Divider()
            Button("清空已完成任务") { store.tasks.removeAll { $0.listID == list.id && $0.isCompleted } }
            Button("删除列表", role: .destructive) { store.deleteList(list.id) }
        }
        .draggable(list.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let source = UUID(uuidString: raw) else { return false }
            store.moveList(source, before: list.id)
            return true
        }
    }

    private func sidebarRow<Content: View>(selection: SidebarSelection, @ViewBuilder content: () -> Content) -> some View {
        Button { store.selection = selection; store.selectedTaskID = nil } label: {
            HStack(spacing: 7, content: content)
                .padding(.horizontal, 8).frame(height: 34)
                .background(store.selection == selection ? Color.white.opacity(0.09) : (hovered == selection ? Color.white.opacity(0.045) : .clear))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { inside in hovered = inside ? selection : nil }
    }

    private func updateList(_ id: UUID, action: (inout TaskListModel) -> Void) {
        guard let index = store.lists.firstIndex(where: { $0.id == id }) else { return }
        action(&store.lists[index])
    }
}

struct EditListSheet: View {
    @ObservedObject var store: AppStore
    let listID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var group = ""
    @State private var color = "8B7CFF"
    private let colors = ["8B7CFF", "41B3A3", "E6A15A", "FF756B", "5DADE2", "D77CE3"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑列表").font(.system(size: 20, weight: .semibold))
            TextField("列表名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("分组（留空可移出分组）", text: $group).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { item in
                    Button { color = item } label: {
                        Circle().fill(Color(hex: item)).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white, lineWidth: color == item ? 2 : 0).padding(-3))
                    }.buttonStyle(.plain)
                }
            }
            HStack { Spacer(); Button("取消") { dismiss() }; Button("保存") { save(); dismiss() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .padding(24).frame(width: 380).background(Theme.panel).preferredColorScheme(.dark)
        .onAppear {
            guard let list = store.lists.first(where: { $0.id == listID }) else { return }
            name = list.name; group = list.group ?? ""; color = list.colorHex
        }
    }

    private func save() {
        guard let index = store.lists.firstIndex(where: { $0.id == listID }) else { return }
        store.lists[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.lists[index].group = group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : group.trimmingCharacters(in: .whitespacesAndNewlines)
        store.lists[index].colorHex = color
    }
}

struct NewListSheet: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var group = ""
    @State private var color = "8B7CFF"
    private let colors = ["8B7CFF", "41B3A3", "E6A15A", "FF756B", "5DADE2", "D77CE3"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("新建列表").font(.system(size: 20, weight: .semibold))
            TextField("列表名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("分组（可选）", text: $group).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { item in
                    Button { color = item } label: {
                        Circle().fill(Color(hex: item)).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white, lineWidth: color == item ? 2 : 0).padding(-3))
                    }.buttonStyle(.plain)
                }
            }
            HStack { Spacer(); Button("取消") { dismiss() }; Button("创建") { store.addList(name: name, color: color, group: group); dismiss() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .padding(24).frame(width: 360).background(Theme.panel).preferredColorScheme(.dark)
    }
}
