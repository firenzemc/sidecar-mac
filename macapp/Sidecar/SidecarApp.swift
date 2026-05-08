import SwiftUI

@main
struct SidecarApp: App {
    @State private var model = DashboardModel()

    var body: some Scene {
        WindowGroup("Sidecar") {
            ContentView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 460)
                .task { await model.start() }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}
