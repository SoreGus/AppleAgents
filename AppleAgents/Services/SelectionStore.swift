import Foundation

struct SelectionStore: Sendable {
    private let defaults: UserDefaults
    private let key = "selected-language-model"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ModelSelection? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ModelSelection.self, from: data)
    }

    func save(_ selection: ModelSelection?) {
        guard let selection,
              let data = try? JSONEncoder().encode(selection) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
