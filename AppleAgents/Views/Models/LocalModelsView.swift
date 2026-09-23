import SwiftUI

struct LocalModelsView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        Group {
            if let error = app.localModels.catalogError {
                ContentUnavailableView(
                    "Local Models Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if app.localModels.catalog.isEmpty {
                ContentUnavailableView(
                    "No Local Models",
                    systemImage: "cpu",
                    description: Text("The bundled model catalog is empty.")
                )
            } else {
                ForEach(app.localModels.catalog) { entry in
                    LocalModelRow(app: app, entry: entry)
                }
            }
        }
    }
}
