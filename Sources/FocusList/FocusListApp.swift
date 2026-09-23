import AppKit
import SwiftUI

@main
struct FocusListApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 880, minHeight: 580)
                .background(WindowAccessor())
                .alert("FocusList", isPresented: Binding(get: { store.alertMessage != nil }, set: { if !$0 { store.alertMessage = nil } })) {
                    Button("好") { store.alertMessage = nil }
                } message: { Text(store.alertMessage ?? "") }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建列表…") { store.showingNewList = true }.keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandMenu("数据") {
                Button("导入 JSON…", action: store.importJSON)
                Button("导出备份…", action: store.exportJSON)
            }
        }
    }
}

struct RootView: View {
    @ObservedObject var store: AppStore
    private let dayRefresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var displayedDay = Date.todayKey

    var body: some View {
        HSplitView {
            SidebarView(store: store).frame(minWidth: 270, idealWidth: 270, maxWidth: 270)
            TaskListView(store: store).frame(minWidth: 330, maxWidth: .infinity)
            if store.selectedTaskID != nil {
                TaskDetailView(store: store).frame(minWidth: 285, idealWidth: 330, maxWidth: 390)
            }
        }
        .background(Theme.background)
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(dayRefresh) { _ in
            if displayedDay != Date.todayKey {
                displayedDay = Date.todayKey
                store.objectWillChange.send()
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { DispatchQueue.main.async { configure(nsView.window) } }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
        window.title = "FocusList"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = NSColor(red: 0.09, green: 0.095, blue: 0.095, alpha: 1)
        window.minSize = NSSize(width: 880, height: 580)
    }
}
