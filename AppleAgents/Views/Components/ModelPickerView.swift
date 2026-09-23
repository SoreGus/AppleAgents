import SwiftUI

struct ModelPickerView: View {
    let title: String
    let models: [ModelDescriptor]
    let selectedModel: ModelSelection?
    let select: (ModelSelection) -> Void

    var body: some View {
        if models.isEmpty {
            ContentUnavailableView(
                "No Models Available",
                systemImage: "cpu",
                description: Text("Configure a remote model or install a local model first.")
            )
        } else {
            Picker(title, selection: selectionBinding) {
                ForEach(models) { model in
                    Text("\(model.name) · \(model.category.rawValue)")
                        .tag(model.selection)
                }
            }
        }
    }

    private var selectionBinding: Binding<ModelSelection> {
        Binding(
            get: { selectedModel ?? models[0].selection },
            set: select
        )
    }
}
