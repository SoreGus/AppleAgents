import SwiftUI

struct ContentView: View {
    @State private var app = AppViewModel()

    #if DEBUG
    @State private var isDiagnosticsSelected = false
    #endif

    var body: some View {
        @Bindable var app = app

        NavigationSplitView {
            List(selection: $app.destination) {
                ForEach(AppDestination.allCases) { destination in
                    Label(destination.title, systemImage: destination.symbol)
                        .tag(destination)
                }

                #if DEBUG
                Section("Debug") {
                    Button {
                        isDiagnosticsSelected = true
                        app.destination = nil
                    } label: {
                        Label(
                            "Diagnostics",
                            systemImage: "waveform.path.ecg"
                        )
                    }
                }
                #endif
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
        #if DEBUG
        if isDiagnosticsSelected {
            DiagnosticsView()
        } else {
            mainDestinationView
        }
        #else
        mainDestinationView
        #endif
    }

    @ViewBuilder
    private var mainDestinationView: some View {
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
