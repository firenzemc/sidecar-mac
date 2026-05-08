import SwiftUI

struct ContentView: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        @Bindable var model = model

        GridOverview()
            .background(model.theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Picker("Mode", selection: $model.dataSource) {
                        Text("Live").tag(DataSource.live)
                        Text("Mock").tag(DataSource.mock)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                ToolbarItem(placement: .primaryAction) {
                    Picker("Theme", selection: $model.theme) {
                        ForEach(Theme.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refreshNow() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Rediscover peers and refresh")
                }
            }
    }
}
