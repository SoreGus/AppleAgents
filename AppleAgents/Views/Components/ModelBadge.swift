import SwiftUI

struct ModelBadge: View {
    let descriptor: ModelDescriptor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: descriptor.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(descriptor.category.rawValue) · \(descriptor.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
