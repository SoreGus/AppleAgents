import SwiftUI

struct ContentView: View {
    @State private var app = AppViewModel()

    var body: some View {
        @Bindable var app = app

        NavigationSplitView {
            List(AppDestination.allCases, selection: $app.destination) { destination in
                Label(destination.title, systemImage: destination.symbol)
                    .tag(destination)
            }
            .navigationTitle("AppleAgents")
        } detail: {
            destinationView
        }
        .task {
            await app.prepare()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { app.presentedError != nil },
                set: { if !$0 { app.presentedError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                app.presentedError = nil
            }
        } message: {
            Text(app.presentedError ?? "")
        }
        .alert(
            "AppleAgents",
            isPresented: Binding(
                get: { app.confirmationMessage != nil },
                set: { if !$0 { app.confirmationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                app.confirmationMessage = nil
            }
        } message: {
            Text(app.confirmationMessage ?? "")
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch app.destination ?? .chat {
        case .chat:
            ChatView(app: app)
        case .models:
            ModelsView(app: app)
        case .settings:
            SettingsView(app: app)
        }
    }
}

#Preview {
    ContentView()
}
