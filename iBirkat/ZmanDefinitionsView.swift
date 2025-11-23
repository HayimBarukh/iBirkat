import SwiftUI

struct ZmanDefinitionsView: View {

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(halachicZmanSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.headline)
                            .padding(.horizontal, 4)

                        ForEach(section.zmanim) { zman in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(zman.name)
                                    .font(.subheadline.weight(.semibold))

                                ForEach(zman.opinions) { op in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(alignment: .top, spacing: 6) {
                                            Text("•")
                                            Text(op.title)
                                                .font(.footnote)
                                        }
                                        if let note = op.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 14)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.gray.opacity(0.07))
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("שיטות הזמנים")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    NavigationStack {
        ZmanDefinitionsView()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
